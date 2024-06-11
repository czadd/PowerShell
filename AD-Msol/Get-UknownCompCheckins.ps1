<#
.Synopsis
   Get computers that are checking in, but do not exist in AD.
.DESCRIPTION
   This script queries the event log for events 5723 and 5805 to identify computers that are checking in to domain controllers, but do not exist in AD. The script will query event logs for these "rouge" computers, then validate whether they exist in AD and/or can be contacted bia ping. These logs are noisy and roll over often, so find a cadence where these are caught, but don't result in too many duplicates.
.EXAMPLE
   PS >Get-UnknownCompCheckins.ps1
   Gets events from all DCs in the current site. To perform thismanually, use the syntax: -DomainController (Get-ADDomainController -filter * | Where site -eq (Get-ADReplicationSite).Name)
.EXAMPLE
   PS >Get-UnknownCompCheckins.ps1 -DomainController 'DC1.corp.co.com','DC2.corp.co.com'
   Designates multiple domain controllers to query. 
.EXAMPLE
   PS >Get-UnknownCompCheckins.ps1 -DomainController (Get-ADDomainController -filter *).name
   Query all domain controllers.
.EXAMPLE
   PS >Get-UnknownCompCheckins.ps1 -DomainController (Get-ADDomainController -filter *).name -SkipTests
   Query all domain controllers, but skip connectivity tests.
.EXAMPLE
   PS >Get-UnknownCompCheckins.ps1 | Send-Mailmessage -To someone@somewhere.com -From reportthing@somwhere.com -Subject 'Report name' -Body "$($_)"
 .NOTES
   Create by Chad Smith, Insight, 6/10/2024.
#>

[CmdletBinding()]
Param(
    [Parameter(Mandatory=$false,ValueFromPipelineByPropertyName=$true,Position=0)][String[]]$DomainController = (Get-ADDomainController -filter * | Where site -eq (Get-ADReplicationSite).Name),
    [Parameter(Mandatory=$false)][Switch]$SkipTests
)


$Evt5723 = Foreach( $DC in $DomainController ){ 
    Write-Verbose "Querying $($DC) event logs for EventID 5723"
    Get-EventLog -ComputerName $DC -LogName System -Newest 10 -InstanceId 5723 
}
$Evt5805 = Foreach( $DC in $DomainController ){ 
    Write-Verbose "Querying $($DC) event logs for EventID 5805"
    Get-EventLog -ComputerName $DomainController -LogName System -Newest 10 -InstanceId 5805  
} 

$Pattern = "(?<=\').+?(?=\')"  #Regex pattern to extract the computer name from between single quotes
$EvtList = Foreach( $Evt in $Evt5723 ){
    $flin = ($evt.Message -split '\n')[0] #Grab the first line
    $Evt | select TimeGenerated, @{l='ComputerName';e={(([regex]::Matches($flin, $Pattern) ).value).Trim()}}
}

$Pattern = "(?<=computer)(.*)(?=failed)" #Regex pattern to extract the computer name from between "computer" and "failed"
$EvtList += Foreach( $Evt in $Evt5805 ){
    $flin = ($evt.Message -split '\n')[0] #Grab the first line
    #(([regex]::Matches($flin, $Pattern) ).Groups[1].value).trim()
    $Evt | select TimeGenerated, @{l='ComputerName';e={(([regex]::Matches($flin, $Pattern) ).value).Trim()}}
}

$EvtList = $EvtList | Sort Computername -Unique | Sort TimeGenerated #Remove duplicates

If( -not $SkipTests ){
    $TestResult = Foreach( $Comp in $EvtList ){
        If( $EvtList.count -gt 1){ Write-Progress -id 0 -Activity 'Testing Computers' -Status "$($Comp.Computername)" -PercentComplete ([Array]::IndexOf($EvtList,$Comp) /$EvtList.Count*100) }
     
        Write-Progress -id 1 -Activity $Comp.Computername -Status 'AD check' -PercentComplete 33

        Remove-Variable ADC -ErrorAction SilentlyContinue
        Remove-Variable ADComp -ErrorAction SilentlyContinue

        Write-Verbose "Checking AD for $($Comp.Computername)"
        Try{ 
            $ADComp = Get-ADComputer $Comp.Compuername -ErrorAction Stop #Check AD for computer
        }
        Catch{}
    
        If( -NOT $ADComp ){ 
            $Filter = "name -like `"*$($Comp.Computername)*`" "
            Try{ 
                $Del = Get-ADObject -filter $filter -IncludeDeletedObjects -ErrorAction Stop #Check AD deleted objects - kind of slow because it's a filter and searches entire AD
                If( $Del ){ $AdState = 'Deleted' }        
            }
            Catch{}
            If( $Del ){ $ADState = 'Deleted' }
            Else{ $AdState = 'False'  }
        }
        Else{
            If( $ADComp.Enabled -eq 'True' ){ $AdState = 'Enabled' }
            Elseif($ADComp.Enabled -ne 'True'){ $AdState = 'Disabled' }
            Else{ $AdState = 'Unknown' }
        }

        $ADC = [PsCustomobject]@{Name=$Comp.Computername; AD=$AdState; DNS = {}; Ping = {} } 

        Start-Sleep -Milliseconds 250

        Write-Verbose "Checking DNS for $($Comp.Computername)"

        If( Resolve-DnsName $Comp.Computername -ErrorAction SilentlyContinue){ $ADC.DNS = $True } 
        Else{  $ADC.DNS = $False }
        Write-Progress -id 1 -Activity $Comp.Computername -Status 'DNS check' -PercentComplete 66
        Start-Sleep -Milliseconds 250
    
        Write-Verbose "Pinging $($Comp.Computername)"  

        Write-Progress -id 1 -Activity $Comp.Computername -Status 'Ping check' -PercentComplete 85
        If( -not $ADC.DNS ){ $ADC.Ping = $False}
        Else{ 
            $ADC.Ping = Test-Connection $Comp.Computername -Quiet
        }
        Write-Progress -id 1 -Activity $Comp.Computername -Completed
        $ADC
    }
    If( $Evtlist.Count -gt 1 ){ Write-Progress -id 0 -Activity $Comp -Completed }

    $TestResult
}
Else{
    Write-Warning 'Connectivity tests skipped'
    $EvtList
}
