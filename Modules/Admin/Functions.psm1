#####################################################################
# Various functions
#####################################################################

Function Add-AdminHelp{ #Add help for our custom functions
    Param(
    [Parameter(Mandatory=$true,Position=0)][String]$AliasName,
    [Parameter(Mandatory=$false)][String]$AliasDefinition,
    [Parameter(Mandatory=$true)][String]$Description,
    [Parameter(Mandatory=$true)][Alias("Example","eg")][String]$Examples
    )

    $Alias = Get-Alias $AliasName
    If( $Examples.Contains(';') ) { $Examples = $Examples -replace ';',"`n" }
   

    $ObjHelp = New-Object –TypeName PSObject
    $ObjHelp | Add-Member –MemberType NoteProperty –Name Command –Value $Alias.Name.tolower()
    $ObjHelp | Add-Member –MemberType NoteProperty –Name Action –Value $Alias.Definition
    $ObjHelp | Add-Member –MemberType NoteProperty –Name Description –Value $Description
    $ObjHelp | Add-Member –MemberType NoteProperty –Name Examples –Value $Examples
    If( $Global:AdminHelp.name -contains $Alias.Name ) { Write-Host "$AliasName already exists" }
    Else{ $Global:AdminHelp += $ObjHelp }
    
}

Function Show-AdminHelp{ 
    $cmd = $Global:AdminHelp | sort -Unique command | Out-GridView -Title "Admin function help (Select a command and click OK to execute)" -PassThru
    if( $cmd ) { & $cmd.Action ; $cmd = {} }
}
Set-Alias -Name ahelp -Value Show-AdminHelp -Description "AdminCustom"
Add-AdminHelp -AliasName ahelp -Description "Displays help for admin commands" -Examples "ahelp"


#region 'go' command and targets

If( -not $Global:go_locations ){
    $GLOBAL:go_locations = @{}
    if( $GLOBAL:go_locations -eq $null ) {
	    $GLOBAL:go_locations = @{}
    }
}

If( -not (get-command set-directory -ErrorAction SilentlyContinue) ){
    function set-directory ([string] $location) {
	    if( $go_locations.ContainsKey($location) ) {
		    set-location $go_locations[$location];
	    } else {
		    write-host "Go locations:" -ForegroundColor Green;
		    $go_locations.GetEnumerator() | sort name | ft -AutoSize;
            write-output "Syntax: go <location>    e.g. go scripts`n"
	    }
    }
    Set-Alias -name go -value Set-Directory -description "admincustom"
}
Add-AdminHelp -AliasName go -Description "Go to a directory" -Examples "1: go scripts;2: go (displays choices)"

If( -Not ($go_locations.home) ){ $go_locations.Add("home", (get-item ([environment]::GetFolderPath("MyDocuments"))).Parent.FullName) } 
If( -Not ($go_locations.desktop) ){ $go_locations.Add("desktop", [environment]::GetFolderPath("Desktop")) }
If( -Not ($go_locations.dt) ){ $go_locations.Add("dt", [environment]::GetFolderPath("Desktop")) }
If( -Not ($go_locations.docs) ){ $go_locations.Add("docs", [environment]::GetFolderPath("MyDocuments")) }
If( -Not ($go_locations.recent) ){ $go_locations.Add("recent", [environment]::GetFolderPath("Recent")) }
If( -Not ($go_locations.sashare) ){ $go_locations.Add('SAshare', "\\corp.czadd\shares\Scripts" ) }
If( -Not ($go_locations.h) ){ $go_locations.Add("h", "h:\" ) }
If( Test-path c:\repo\czadd ){
    If( -Not ($go_locations.repo) ){ $go_locations.Add("repo","c:\repo\czadd") }
    If( -Not ($go_locations.sa) ){ $go_locations.Add("SA", 'c:\repo\czadd\sa' ) }
    If( -Not ($go_locations.sa) ){ $go_locations.Add("sa","c:\repo\czadd\sa") }
    If( $Go_locations.scom ){ $go_locations.Remove("scom") }
    $go_locations.Add("scom","c:\repo\czadd\scom") 
    If( $go_locations.msol ){ $go_locations.Remove("msol") }
    $go_locations.Add("msol","c:\repo\czadd\MSOL") 
    If( $go_locations.vmm ){ $go_locations.Remove("vmm") }
    $go_locations.Add("vmm","c:\repo\czadd\vmm") 
    If( $go_locations.sma ){ $go_locations.Remove("sma") }
    $go_locations.Add("sma","c:\repo\czadd\sma")
    If( $go_locations.dpm ){ $go_locations.Remove("dpm") }
    $go_locations.Add("dpm","c:\repo\czadd\dpm")
    If( $go_locations.dfs ){ $go_locations.Remove("dfs") }
    $go_locations.Add("dfs","c:\repo\czadd\dfs")
}

$go = $go_locations
#endregion 'go' command and targets

Function Test-Aduser ($UserName) {
    Try{ If( Get-Aduser $UserName -ErrorAction SilentlyContinue) {$true} }
    Catch{ $false}
}

Function Get-AdPasswordExpirationDate {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$false,ValueFromPipelineByPropertyName=$true,Position=0)][String[]]$AdUser=$env:USERNAME
    )

    Foreach( $User in $Aduser ) {
        If( Test-Aduser $User ){
            get-aduser $User -Properties "msDS-UserPasswordExpiryTimeComputed" |  Select-Object -Property "SamAccountname",@{Name="ExpiryDate";Expression={[datetime]::FromFileTime($_."msDS-UserPasswordExpiryTimeComputed")}}
        }
        Else{ Write-Error "AD user not found: $user" }
    }
}
Set-alias -Name adexp -Value Get-AdPasswordExpirationDate -Description "admincustom"
Set-alias -Name exp -Value Get-AdPasswordExpirationDate -Description "admincustom"
Add-AdminHelp -AliasName adexp -Description "Get user AD password expiration date" -Examples "1: adexp jdoe 2: adext (get-aduser | select -expandproperty samaccountmane)"
Add-AdminHelp -AliasName exp -Description "Get user AD password expiration date" -Examples "1: adexp jdoe 2: adext (get-aduser | select -expandproperty samaccountmane)"

Function Search-DNS{
    #Requires -Version 4.0

    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true,Position=0)]$SearchText,
        [Parameter(Mandatory=$false,ValueFromPipelineByPropertyName=$true,Position=1)]$ZoneName = 'corp.czadd',
        [Parameter(Mandatory=$false,ValueFromPipelineByPropertyName=$true,Position=2)]$DNSServer = 'DC01.corp.czadd',
        [Parameter(Mandatory=$false,ValueFromPipelineByPropertyName=$true,Position=3)][ValidateSet("IPv4","IPv6","All")][String]$Type
    )

    If( $Type -eq 'IPV4' ){ $DnsRecords = Get-DnsServerResourceRecord -ZoneName $ZoneName -RRType "A" -ComputerName $DNSServer }
    ElseIf( $Type -eq 'IPv6'){ $DnsRecords = Get-DnsServerResourceRecord -ZoneName $ZoneName -RRType AAAA -ComputerName $DNSServer }
    Else{ $DnsRecords = Get-DnsServerResourceRecord -ZoneName $ZoneName -ComputerName $DNSServer }
    
    $DnsFound = $DnsRecords.where({$_.HostName -match $SearchText })
    If( $DnsFound.count -lt 1 ) { Write-Warning "No records found for $Searchtext" }
    Else{ $DnsFound | sort HostName }
}    
Set-alias -Name DNSSearch -Value Search-DNS -Description "admincustom"
Add-AdminHelp -AliasName DNSSearch -Description "Search DNS records for a specific string" -Examples "1: DNSSearch blah"

Function Get-AdObjectFromSid {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true,Position=0)][String]$SID
    )
    $objSID = {} ; $obj = {}
    $objSID = New-Object System.Security.Principal.SecurityIdentifier("$ID")
    $obj = $objSID.Translate( [System.Security.Principal.NTAccount])
    $obj.Value
}
Set-Alias -name SidChk -value Get-AdObjectFromSid -Description "admincustom"
Add-AdminHelp -AliasName SidChk -Description "Get AD object from SID" -Examples "1: SidChk;2: SidChk 'S-1-5-21-...'"

Function Get-DiskSpace{
    <#
    .Synopsis
       Get Disk Space
    .DESCRIPTION
       GEt disk space on a server, including mount points. Returns an object that can be sorted, formatted, etc.
       Requires Powershell 3.0 + (otherwise an error may be shown during Test-connection)
    .EXAMPLE
       GetDiskSpace.ps1 -computername SomeComputer
    .EXAMPLE
       GetDiskSpace.ps1 SomeComputer
    #>

    [CmdletBinding()]
    Param
    (
        # Computer Name
        [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true, Position=0)][String[]]$ComputerName
    )

    Foreach( $Computer in $ComputerName){
        try{ $Ping = Test-NetConnection -ComputerName $Computer -InformationLevel Quiet -ErrorAction SilentlyContinue }
        catch{ Write-Warning "Can't to connect to $Computer" }
        If( ! $Ping ){ Write-Warning "$Computer unreachable"}
        Else{

            $ColLogicalDisks = {}
            $ColMountPoints = {}
            $ColLogicalDisks = @()
            $ColMountPoints = @()

            #Get logical disk info
            $LogicalDisks = Get-WmiObject -computername $Computer -Query { Select * From Win32_LogicalDisk WHERE DriveType = 3 AND NOT VolumeName Like "*page*" } | Where { $_.VolumeName -NotMatch "mountpoint" }

            Foreach( $Disk in $LogicalDisks )
            {
                $LdObject = New-Object –TypeName PSObject
                $LdObject | Add-Member -MemberType NoteProperty -Name ComputerName -Value $Computer
                $LdObject | Add-Member –MemberType NoteProperty –Name Name –Value $Disk.Name
                $LdObject | Add-Member –MemberType NoteProperty –Name Label –Value $Disk.VolumeName
                $LdObject | Add-Member –MemberType NoteProperty –Name 'Size (GB)' –Value ( "{0:n2}" -f ($Disk.Size / 1gb) )
                $LdObject | Add-Member –MemberType NoteProperty –Name 'Used (GB)' –Value ( "{0:n2}" -f (($Disk.Size - $Disk.FreeSpace) / 1gb) )
                $LdObject | Add-Member –MemberType NoteProperty –Name 'Free (GB)' –Value ( "{0:n2}" -f ($Disk.FreeSpace / 1gb) )
                $LdObject | Add-Member –MemberType NoteProperty –Name "Free %" –Value ( "{0:n2}" -f ($Disk.Freespace / $Disk.Size  * 100))
                $LdObject | Add-Member –MemberType NoteProperty –Name DriveType –Value "Logical disk"
                $ColLogicalDisks += $LdObject
            }     

            #Get mount point info
            $MountPoints = Get-WmiObject -ComputerName $Computer -query { Select * from Win32_Volume Where FileSystem Like "NTFS"} | Where {$_.Name -Notmatch "Volume" -And !($_.DriveLetter) }
            Foreach( $MP in $MountPoints )
            {
                $MpObject = New-Object –TypeName PSObject
                $MpObject | Add-Member -MemberType NoteProperty -Name ComputerName -Value $Computer
                $MpObject | Add-Member –MemberType NoteProperty –Name Name –Value $MP.Name
                $MpObject | Add-Member –MemberType NoteProperty –Name Label –Value $MP.Label
                $MpObject | Add-Member –MemberType NoteProperty –Name 'Size (GB)' –Value ( "{0:n2}" -f ($MP.Capacity / 1gb) )
                $MpObject | Add-Member –MemberType NoteProperty –Name 'Free (GB)' –Value ( "{0:n2}" -f ($MP.FreeSpace / 1gb) )
                $MpObject | Add-Member –MemberType NoteProperty –Name "Free %" –Value ( "{0:n2}" -f ($mp.Freespace / $mp.Capacity  * 100))
                $MpObject | Add-Member –MemberType NoteProperty –Name DriveType –Value "Mount Point"
                $ColMountPoints += $MpObject
            }

            $ColDisks = $ColLogicalDisks + $ColMountPoints 
            $ColDisks 
        }
    }
} # END Get-DiskSpace

Function Get-DiskspaceFormatted{
    <#
    .SYNOPSIS
        Performs the Get-Diskspace command and returns as a formatted table. 
        To filter, use the get-dispace command directly.
    #> 
    [CmdletBinding()]
    Param
    (
        # Computer Name
        [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true, Position=0)][String[]]$ComputerName
    )
    #Uses the Get-Diskspace function, then sort and return in a table
    Get-DiskSpace $ComputerName | sort  ComputerName,DriveType,Name | ft -auto
}
Set-Alias -Name ds -Value Get-DiskSpaceFormatted -Description "admincustom"
Add-AdminHelp -AliasName ds -Description "Get disk space on a server" -Examples "ds servername"

Function Test-RemoteDesktop {
    [CmdletBinding()]
    Param([Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true,Position=0)][String[]]$computername)
    $result = Foreach( $Computer in $computername ){
        $tst = Test-NetConnection $computer -CommonTCPPort rdp 
        [PsCustomObject]@{ Computername=$Computer;Ping=$tst.PingSucceeded;RDP=$tst.TcpTestSucceeded }
    }
    If( $Result.count -eq 1 ) { $result | ft -a }
    Else{ $Result }
}
Set-Alias -Name trd -Value Test-RemoteDesktop -Description "admincustom"
Add-AdminHelp -AliasName trd -Description "Check ping and RDP on a server" -Examples "Test-RemoteDesktop computer1,computer2"

Function Test-Acl
{
    [CmdletBinding()]
    Param( [Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true,Position=0)][String]$Directory )
    $Access = get-acl $Directory | % { $_.access}
    $access | ft IdentityReference, FileSystemRights, AccessControlType , IsInherited -AutoSize
}
Set-Alias -Name cacl -Value Test-Acl -Description "admincustom"
Add-AdminHelp -AliasName cacl -Description "Check ACL of a folder (or registry key)" -Examples "1: cacl \\servername\iso$; 2: cacl 'HKLM:\SOFTWARE\Microsoft'"

Function Restart-HealthService {
<#
.SYNOPSIS
    Check SCOM HealthService on a server and restart if needed
.EXAMPLE
    Restart-HealthService 
    Prompts for server name.
.EXAMPLE
    Restart-HealthService <computername> -test
    Shows healthservice status. No option to restart the service.
.EXAMPLE
    Restart-HealthService  <computername>
    Queries the server's healthservice state and prompts for restart.
.EXAMPLE
    Restart-HealthService  <computername> -force
    Restarts the HealthService without prompting.
.NOTES
    Function: Restart-HealthService
    Author: csmith
#> 

    [CmdletBinding()]
    Param( 
        [Parameter(Mandatory=$true,Position=0)][string]$ComputerName,
        [Parameter(Mandatory=$false)][ValidateSet('HealthService','SCSM','LogRhythm')][string]$ServiceName='HealthService',
        [Parameter(Mandatory=$false)][Switch]$Force,
        [Parameter(Mandatory=$false,Position=1)][ValidateSet('SCOM','HS','LogRythm','LR','SCSM')][String]$Service = 'SCOM',
        [Parameter(Mandatory=$false)][Switch]$Test,
        [Parameter(Mandatory=$false)][Switch]$Repair
    )

    Switch( $Service ){
        'SCOM'     { $ServiceName = 'HealthService' }
        'HS'       { $ServiceName = 'HealthService' }
        'LogRhythm' { $ServiceName = 'SCSM' }
        'LR' { $ServiceName = 'SCSM' }
        'SCSM' { $ServiceName = 'SCSM' }
    }

    $Conn = test-connection -count 1 -computername $ComputerName -Quiet 
    If( !$conn ) {Throw "Unable to connect to $ComputerName. It is either offline or cannot be pinged (e.g. it may be in the DMZ)" }

    $SvcStatus = Get-Service -Name $ServiceName -ComputerName $ComputerName -ErrorAction SilentlyContinue
    If( ! $SvcStatus ) { Throw "$($Servicename) not found on $Computername. Perhaps it uses agentless monitoring." } #If healthservice not found, return false
    Else{ 
        $SvcStatus 
        If( $Test ) { Write-Host ; break } 
    }

    If( $Repair -and ($ServiceName -eq 'HealthService') ){
        Repair-ScomHealthServiceDatastore $ComputerName
        Restart-HealthService -ComputerName $ComputerName -Test
    }
    
    If( !$Force ) { 
        Do{ 
            $Restart = Read-Host "Restart $($ServiceName)? (y/n)" } 
            Until ($Restart -match "[yn]" )
        } 
        If( $Restart -eq "n" ) { return }
    Else{ 
        Write-Output "Restarting $($ServiceName)..."
        If( $SvcStatus.Status -ne "Running" ) {$SvcStatus | Start-service -PassThru }
        Else { $SvcStatus | Restart-Service -PassThru }
        If( $SvcStatus.Status -ne "Running" ) {
            Write-Warning "Healthservice is not running. Trying again."
            $SvcStatus | Start-service -PassThru 
        } 
    }
} #END Restart-Healthservice
Set-alias -name hs -Value Restart-HealthService -Description "admincustom"
Add-AdminHelp -AliasName hs -Description "Restart SCOM health service" -Examples "1: hs servername;2: hs"

Function Repair-ScomHealthserviceDatastore{
    <#
    .Synopsis
       Repairs the SCOM healthservice datastore.
    .DESCRIPTION
       Repairs the SCOM healthservice datastore by stopping the service, deleting the datastore, and restarting the service so it can rebuild it. This is usually executed in reaction to the SCOM alert stating "System Center Management Health Service Unloaded System Rule(s)." If this alert occurs on a cluster node, it can result in "Cluster resource Group offline or partially online" alerts for all VMs on the cluster node. This is because the SCOM agent was unable to load the system rules for the cluster and, because it can't fiture out the state, the SCOM agent defaults to the safest option: reporting failure.
    .EXAMPLE
       PS:> .\Repair-HealthServiceDatastore.Ps1 -Computername thatcomputer
       Repairs the datastore on a single computer.
    .EXAMPLE
       PS:> .\Repair-HealthServiceDatastore.Ps1 -Computername 'thatcomputer','othercomputer','yetanothercomputer'
       Repairs the datastore on multiple single computers.
    #>
    [CmdletBinding(DefaultParameterSetName='ByComputerName')]
    Param(
        # Computer Name
        [Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true,Position=0,Parametersetname='ByComputerName')][String[]]$ComputerName,
        # Virtual path to the health service datastore
        [Parameter(Mandatory=$false,ValueFromPipelineByPropertyName=$true)][String]$HsStoreBasePath = 'c$\Program Files\Microsoft Monitoring Agent\Agent\Health Service State\Health Service Store'
    )

    Write-Verbose "$ComputerName"

    Foreach( $Computer in $ComputerName){
        If( $ComputerName.count -gt 1 ){ Write-Output "=====$Computer=====" }
        $HsStorePath = join-path "\\$Computer" $HsStoreBasePath
        If( ! (Test-Connection $Computer -Count 1 -Quiet) ){ Throw "$Computer not reachable via ping" }
        If( ! (test-path $HsStorePath) ){ Throw "HealthService store not found: $HsStorePath" }

        get-service -Name HealthService -ComputerName $Computer | Stop-Service -PassThru

        Start-sleep -Seconds 1
        If( (get-service -Name HealthService -ComputerName $Computer).Status -notmatch 'Stopped' ){ Throw "Unable to stop HealthService on $Computer" }

        Write-Output "Removing datastore"
        Remove-Item $HsStorePath -Recurse -Force

        get-service -Name HealthService -ComputerName $Computer | Start-Service
    }

}

Function Move-OU{
     <#
    .SYNOPSIS
        Move a computer to a specified OU. Will prompt for computer.
            Workstations OU by default
    .EXAMPLE
        Move-OU "SomeComputer 
        
        Moves the computer to the Workstations OU

    .EXAMPLE
        Move-OU -Computername "SomeComputer" -OU "Some OU"
        Move-OU  SomeComputer "Some OU" 

        Moves the computer to the designated OU

    #> 

    [CmdletBinding()]
    Param(
    [Parameter(Mandatory=$true,Position=0)][ValidateScript({ get-adcomputer $_.trim() })]$ComputerName,
    [Parameter(Mandatory=$false,Position=1)][ValidateScript({ Get-ADOrganizationalUnit -filter 'name -eq $_'  })][String]$OU = "Workstations",
    [Parameter(Mandatory=$false)] [Switch]$Multiple #Maybe make into a filepath that implies multiple?
    )

    If(!(Get-Module ActiveDirectory) ) {import-module activedirectory}

    $ComputerName = $ComputerName.Trim()
    $OU = $OU.Trim()

    #abort if already in the desired OU
    If( (get-adcomputer $ComputerName | select -ExpandProperty Name) -match $OU )  
    {Write-Host "$ComputerName is already in the '$OU' OU"}
    Else #Do it and verify computer object is moved to the desired OU
    { 
        Get-AdComputer $ComputerName | Move-ADObject -targetpath (Get-ADOrganizationalUnit -filter 'name -eq $ou' )
        IF( (Get-ADComputer $ComputerName).DistinguishedName -match $OUtarget.name ) 
        {
            Write-Host "Moved $Computername to $OU" -ForegroundColor green
        }
        Else
        {
            Write-Host "Unable to move $Computername to $OU" -ForegroundColor Red
        }
    }
} #END Move-OU  

Set-Alias -Name mou -Value Move-OU -Description "admincustom"
Add-AdminHelp -AliasName mou -Description "Move a computer to a new OU" -Examples "1: mou  SomeComputer 'Some OU';2: mou ComputerName (moves to Workstations)"

Function Get-VmmHostServer
{
  [CmdletBinding()]
  Param( [Parameter(Mandatory=$true,Position=0)] [String]$ComputerName   )
  Get-SCVirtualMachine -name $ComputerName | ft Name, VmHost -autosize
}
Set-Alias -Name vmmh -Value Get-VmHostServer
Add-AdminHelp -AliasName vmmh  -Description "Get a VM's host" -Examples "1: vmmh ComputerName"

Function Get-VmInfo{
  [CmdletBinding()]
  Param(
      # Name of VM to check
      [Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true,Position=0)][String]$ComputerName,
      # The default return is "simple" and fits on a single line. Use the -details switch to return detailed information.
      [Parameter(Mandatory=$false,ValueFromPipelineByPropertyName=$true,Position=1)][Alias('d','detail')][Switch]$Details
  )


  $vm =  Get-SCVirtualMachine -Name $ComputerName | select ComputerName,CPUCount,CPUUtilization,DiskResources,DynamicMemoryBufferPercentage,DynamicMemoryDemandMB,DynamicMemoryEnabled,DynamicMemoryMaximumMB,DynamicMemoryStatus,HasPassthroughDisk,HasSavedState,HAVMPriority,HostGroupPath,IsHighlyAvailable,IsOrphaned,Location,Memory,MemoryAssignedMB,MemoryAvailablePercentage,Name,OperatingSystem,StartAction,Status,VirtualHardDisks,VirtualMachineState,VirtualNetworkAdapters,VMAddition,VMCheckpoints,VMHost,VMResourceStatus -ErrorAction SilentlyContinue
  If( ! $VM ){ Throw "$ComputerName not found. Check whether it is a valid VM managed by SCVMM" }

  If( $Details ) {
      $vm
  }
  Else{
      If( $VM.DynamicMemoryEnabled -match 'true' ) {
          $mem = $VM.DynamicMemoryDemandMB.ToString() + "/" + $VM.DynamicMemoryMaximumMB.ToString()
          [PsCustomObject]@{name=$vm.Name;Status=$vm.Status;VmHost=$vm.vmhost;CPU=$vm.cpucount;MemUsed=$VM.DynamicMemoryDemandMB;MemMax=$VM.DynamicMemoryMaximumMB} 
      }
      Else{
          $VM | select Name,Status,Vmhost,CpuCount,MemoryAssignedMB 
      }
  }
}
Set-Alias -Name vmi -Value Get-VmInfo
Add-AdminHelp -AliasName vmi -Description "Get VM info" -Examples "1: gvi ComputerName;2: gvi Computername -detailed"

Function Get-MsolCred ([Switch]$NoSave){
    Write-Verbose "Get MSOL creds from username"
    $CredPath = Join-path $env:appdata "msolcred.xml"
    If( -not (Test-Path $CredPath) ) 
    { 
        Write-Verbose "No saved creds.  Get new creds."
        $LiveCred = Get-credential -Credential ($env:USERNAME + "@czadd.com") 
        If( ! $NoSave ){ $LiveCred | Export-Clixml $CredPath }
    }
    Else
    {
        Write-Verbose "Use saved creds"
        $LiveCred = Import-Clixml $CredPath
    }
    $LiveCred
}
Set-Alias -name mc -value Get-MsolCred
Add-AdminHelp -AliasName mc -Description "Get saved credential from file. Create it if it doesn't exist" -Examples "1: mc;2: mc -NoSave"

function Start-ElevatedPsSession{ 
    #Open a new elevated powershell window
    If( ! (Test-Administrator) ){
        if( $host.name -match 'ISE' ) { start-process PowerShell_ISE.exe -Verb runas }
        Else{ start-process powershell -Verb runas }
    }
    Else{ Write-Warning "Session is already elevated" }
} 
Set-Alias -Name su -Value Start-ElevatedPsSession

Function Get-ADComputerPassword{
    <#
    .Synopsis
       Get local administrator password from AD
    .EXAMPLE
       Get-ADComputerPassword.ps1 SomeComputer
       Displays local admin password for a single computer.
    .EXAMPLE
       Get-ADComputerPassword.ps1 ServerOne,ServerTwo,ServerThree
       Displays local admin password for multiple computers.
    #>
    Param(
        [Parameter(Mandatory=$true,Position=0)][String[]]$ComputerName
    )
    
    Foreach( $Computer in $Computername ){
        Try{ Get-Adcomputer $Computer -Properties ms-Mcs-AdmPwd,ms-Mcs-AdmPwdExpirationTime | Select @{L='ComputerName';e={$_.Name}},@{l='ComputerPassword';e={$_.'ms-Mcs-AdmPwd'}},@{l='PasswordExpiration';e={[datetime]::FromFileTime($_.'ms-Mcs-AdmPwdExpirationTime')}} -ErrorAction Stop }
        Catch{ Write-Warning "'$Computer' not found" }
    }

}
Set-Alias -Name cpw -Value Get-ADComputerPassword -Description "admincustom"

#region General helper functions
function Find-Files ([string] $glob) { get-childitem -recurse -include $glob }
Set-Alias -Name ff -Value Find-Files -Description "admincustom"
Add-AdminHelp -AliasName ff -Description "Find files (recursively" -Examples "1: ff *blah*"

function Start-logoff { shutdown /l /f } #This would be handy w/ a computername and username argument, too
Set-Alias -name logoff -Value Start-logoff -Description "admincustom"
Add-AdminHelp -AliasName logoff -Description "Log off the current user" -Examples "Logoff"

function Remove-Directory ([string] $glob) { remove-item -recurse -force $glob }
Set-Alias -Name rmd -value Remove-Directory -Description "admincustom"
Add-AdminHelp -AliasName rmd -Description "Remove Directory & child items (like deltree)" -Examples "Rmdir d:\somedir"

function Remove-FileExtention ([string] $filename) { [system.io.path]::getfilenamewithoutextension($filename) } 
Set-Alias -name stripext -value Remove-FileExtention -Description "admincustom"
Add-AdminHelp -AliasName stripext -Description "Strip filename extension" -Examples "stripext something.txt"

function Find-StringInFiles 
{
    Param(
    [Parameter(Mandatory=$true,Position=0)][string]$glob,
    [Parameter(Mandatory=$false,Position=1)][String]$path,
    [Parameter(Mandatory=$false)][Alias("r")][switch]$Recurse
    )
     
    If( $Recurse ) {get-childitem $path -recurse | select-string -pattern $glob | group path | select name } 
    Else {get-childitem $path | select-string -pattern $glob | group path | select name }     
}
Set-Alias -name fs -value Find-StringInFiles -Description "admincustom"
Add-AdminHelp -AliasName fs -Description "Search inside files for strings" -Examples "1: fs sometext;2: fs sometext *.txt -recurse"

#Get clipboard text
function Get-ClipboardText(){
    Add-Type -AssemblyName System.Windows.Forms
    $tb = New-Object System.Windows.Forms.TextBox
    $tb.Multiline = $true
    $tb.Paste()
    ($tb.Text).trim()
} #END Get-ClipboardText
Set-Alias -Name clip -Value Get-ClipboardText -Description "admincustom"
Add-AdminHelp -AliasName clip -Description "Get text from clipboard" -Examples "clip"

function Test-Administrator {  
    $user = [Security.Principal.WindowsIdentity]::GetCurrent()
    (New-Object Security.Principal.WindowsPrincipal $user).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)  
}

#Display info at startup
Function Start-Profile{
  #Clear-Host 
    $ver = $PSVersionTable.PSVersion.major.ToString() +"."+ $PSVersionTable.psversion.minor.tostring()
    $TitleBarText = $env:COMPUTERNAME.ToLower() + " PowerShell " + $ver
    If( get-variable psISE -ErrorAction SilentlyContinue ) { $TitleBarText = $TitleBarText + " ISE" ; $psise.Options.RestoreDefaults() }
    If( Test-Administrator ) 
    { 
        $TitleBarText = $TitleBarText + " (Administrator)"  
    }
    If( -not (get-variable psISE -ErrorAction SilentlyContinue) ){
        $backgroundcolor = [console]::backgroundcolor
        $p = $host.privatedata
        $p.ErrorForegroundColor    = "Red"
        $p.ErrorBackgroundColor    = $backgroundcolor
        $p.WarningForegroundColor  = "Yellow"
        $p.WarningBackgroundColor  = $backgroundcolor
        $p.DebugForegroundColor    = "Yellow"
        $p.DebugBackgroundColor    = $backgroundcolor
        $p.VerboseForegroundColor  = "Cyan"
        $p.VerboseBackgroundColor  = $backgroundcolor
        $p.ProgressForegroundColor = "Yellow"
        $p.ProgressBackgroundColor = $backgroundcolor
    }

    $Host.UI.RawUI.WindowTitle = $TitlebarText
    #cls
    If( -not (Test-Administrator) ){ Write-Host "Windows Powershell $ver ($($env:USERNAME)'s profile)" -ForegroundColor Green }
    Else{ Write-Host "Windows Powershell $ver (Administrator profile)" -ForegroundColor Green }
    Write-Host "Execution Policy:" (Get-ExecutionPolicy)
    Write-Host "To display admin commands, type " -nonewline ; Write-Host "ahelp" -ForegroundColor yellow
    Write-Host "To display go locations, type " -nonewline ; Write-Host "go" -ForegroundColor yellow
    Write-Host #Blank line
} #END Start-Profile
Set-Alias -name admin -value start-profile -description "admincustom"
Add-AdminHelp -AliasName admin -Description "Display session startup info" -Examples "admin"
#endregion General helper functions

Function ConvertTo-LocalTime($UTCTime)
{
    $strCurrentTimeZone = (Get-WmiObject win32_timezone).StandardName
    $TZ = [System.TimeZoneInfo]::FindSystemTimeZoneById($strCurrentTimeZone)
    $LocalTime = [System.TimeZoneInfo]::ConvertTimeFromUtc($UTCTime, $TZ)
    Return $LocalTime
}
Set-Alias -name ctl -value ConvertTo-LocalTime -description "admincustom"
Add-AdminHelp -AliasName ctl -Description "Convert UTC time to local time" -Examples "ConvertTo-LocalTime `$Somedate"

#region Aliases
Set-Alias -name np -value "C:\Windows\System32\notepad.exe" -description "admincustom" | out-null
Add-AdminHelp -AliasName np -Description "Start notepad" -Examples "1: np;2: np somefile.txt"

Set-Alias -name npp -value "C:\Program Files (x86)\Notepad++\notepad++.exe" -description "admincustom" | out-null
Add-AdminHelp -AliasName npp -Description "Start notepad plus" -Examples "1: npp;2: npp somefile.txt"

Set-Alias -name pss -value Enter-PsSession -description "admincustom" | out-null
Add-AdminHelp -AliasName pss -Description "Open a PS Session to another computer" -Examples "1: pss;2: pss SomeServer"

Set-Alias -name ih -value invoke-history
Set-Alias -name Get-ScVm -Value Get-SCVirtualMachine
Set-Alias -name Get-ScVhd -Value Get-SCVirtualHardDisk

Set-Alias -name gpw -Value Get-AdmPwdPassword
Set-Alias -name rpw -Value Reset-AdmPwdPassword
#endregion Aliases

#Export stuff to the parent
export-modulemember -function * -variable * -alias * -Cmdlet *
