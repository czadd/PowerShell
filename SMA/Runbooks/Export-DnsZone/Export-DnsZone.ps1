<#
.Synopsis
    SMA workflow to export a DNS zone to file. This is intended to run from SMA on a schedule.
.DESCRIPTION
    Export a DNS zone to file. This is a method to backup DNS zones in case of accidental deletion. Import into DNS to restore a zone. 
.EXAMPLE
    PS:> Export-DnsZone.ps1 -Computername someserver.corp.co -DnsServername dnsserver.corp.co -DnsRemotePath \\dnsserver\c$\somepath -DnsBackupRootPath \\CorporateShare.corp.co\sub\sub -AdCredential <some credential saved in SMA>
.NOTES
   Please note, this requires Windows Server 2012 R2 because Windows 2008 does not support the dnsserver module.  This is the reason for the -computername parameter. Use a Windows Server 2012 R2 server as the computername if the DNS server is Windows Server 2008. If the DNS Server is Windows Server 2012 R2 or greater, the computername and dnsservername can match.
#>


Workflow Export-DnsZone{
    Param(
        #Computer to run the inlinescript from. This must be Windows Server 2012 R2 or greater because Windows Server 2008 does not have the dnsserver PowerShell module.
        [Parameter(Mandatory=$true)][String]$ComputerName,
        #DNS server name 
        [Parameter(Mandatory=$true)][String]$DnsServername, 
        #Path DNS backups will be copied to
        [Parameter(Mandatory=$true)][String]$DnsBackupRootPath,
        #Credential of user who can manage DNS
        [Parameter(Mandatory=$true)][String]$AdCredential,
        #Number of days to keep DNS backups
        [Parameter(Mandatory=$false)][Int]$Keepdays=7
    )

    $DnsBackupPath = Join-Path -Path $DnsBackupRootPath (get-date -f yyyy.MM.dd).ToString()
    $DnsServerPath = join-path "\\$($DnsServername)" 'c$\windows\System32\dns'
    $InlineScriptCred = Get-AutomationPSCredential -Name $ADCredential 

    $Result = inlinescript{
        $VerbosePreference = [System.Management.Automation.ActionPreference]$VerbosePreference

        If( -not (test-path -Path $USING:DnsBackupRootPath) ){ New-Item -Path $USING:DnsBackupRootPath -ItemType Directory -ErrorAction SilentlyContinue }
        If( -not (Test-Path -Path $USING:DnsBackupPath) ){ New-Item -Path $USING:DnsBackupPath -ItemType Directory -ErrorAction SilentlyContinue }

        Import-Module DnsServer -verbose:$false
        $Zonelist = Get-DnsServerZone -ComputerName $USING:DnsServername | Where { ($_.ZoneName -ne 'TrustAnchors') -and ($_.IsAutoCreated -eq $False) }
        Foreach( $Zone in $Zonelist ){
            $DnsFileName = $Zone.ZoneName + '.dns'
            If( test-path (Join-Path $USING:DnsServerPath $DnsFileName) ){ Remove-Item (Join-Path $USING:DnsServerPath $DnsFileName) -Force }
            start-sleep -Milliseconds 100
            Export-DnsServerZone -ComputerName $USING:DnsServername -Name $Zone.ZoneName -FileName $DnsFileName -PassThru
            $i = 0
            Do{ 
                $i++
                $DnsFileChk = Test-path (Join-Path $USING:DnsServerPath $DnsFileName) 
                Start-sleep -Seconds 1 
            } 
            Until( ($DnsFileChk -eq $True) -or ($i -ge 30) )
            Copy-Item -Path  (Join-Path $USING:DnsServerPath $DnsFileName) -Destination $USING:DnsBackupPath -Force
            Write-Output "$($Zone.ZoneName) -> $(Join-Path $USING:DnsBackupPath $DnsFileName)"
        }
    } -PSComputerName $ComputerName -PSCredential $InlineScriptCred

}

#TODO: Clean up old stuff based on keepdays

#  Export-DnsZone -ComputerName somecomputer -DnsserverName dc01 -DnsBackupRootPath '\\server\share\DnsBackup' -AdCredential 'Domain RO' -verbose
#  $JobParams = @{ADCredential="Domain RO";ComputerName="somecomputer";DnsServerName="dc01";DnsBackupRootPath="\\corp.czadd\share\dnsbackup";Keepdays=7}
#  $JobId = Start-SmaRunbook  -WebServiceEndpoint $smaweb -Name Export-DnsZone -Parameters $JobParams
#  Get-SmaJob -Id $JobId -WebServiceEndpoint $smaweb 
#  Get-SmaJobOutput -WebServiceEndpoint $smaweb -Id $JobId -Stream Any  
