#region Functions used while setting up the profile

function script:append-path {
	$oldPath = get-content Env:\Path
	$newPath = $oldPath + ";" + $args
	set-content Env:\Path $newPath
}

#endregion

#region common variables that I like to use

#Set up some variables for everyday use
$ModulePath = "c:\scripts\czadd\Modules"
$env:psmodulepath = $env:psmodulepath +";" +$ModulePath  
set-item -path env:HOME -value (get-item ([environment]::GetFolderPath("MyDocuments"))).Parent.FullName  #Redirecting this back to the default becase AD sets it to a networked directory

#Default values for cmdlets
$PSDefaultParameterValues = @{
    "get-help:showwindow"         = $True;
}

#Make a variable for my personal creds
$CredPath = Join-path $env:appdata "msolcred.xml"
If( Test-Path $CredPath){ $MC = Import-Clixml $CredPath }

#Append the path
If( $env:path -notlike "*$((Join-Path ([environment]::GetFolderPath("MyDocuments")) "WindowsPowerShell"))*" ){ append-path Join-Path ([environment]::GetFolderPath("MyDocuments")) "WindowsPowerShell" }
If( $env:path -notlike "*$((Join-Path ([environment]::GetFolderPath("MyDocuments")) "WindowsPowerShell"))*" ){ append-path Join-Path ([environment]::GetFolderPath("MyDocuments")) "WindowsPowerShell\Modules" }

#endregion

#region 'Go' command and go locations
$GLOBAL:go_locations = @{}
if( $GLOBAL:go_locations -eq $null ) {
	$GLOBAL:go_locations = @{}
}

function set-directory ([string] $location) {
	if( $go_locations.ContainsKey($location) ) {
		set-location $go_locations[$location];
	} else {
		write-host "Go locations:" -ForegroundColor Green;
		$go.GetEnumerator() | sort name | ft -AutoSize;
        write-output "Syntax: go <location>    e.g. go scripts`n"
	}
}
Set-Alias -name go -value Set-Directory 
Add-AdminHelp -AliasName go -Description "Go to a directory" -Examples "1: go scripts;2: go (displays choices)"

$go_locations.Add("home", $Env:home)
$go_locations.Add("desktop", [environment]::GetFolderPath("Desktop"))
$go_locations.Add("dt", [environment]::GetFolderPath("Desktop"))
$go_locations.Add("docs", [environment]::GetFolderPath("MyDocuments"))
$go_locations.Add("recent", [environment]::GetFolderPath("Recent"))

# Grab each directory from scripts dir and add to the list
$GoDirs = Get-ChildItem $go_locations.scripts -Directory
Foreach( $dir in $GoDirs ) { $go_locations.add( $dir.name.ToLower(),(Join-Path $go_locations.scripts $dir.name) ) }
$go = $go_locations

#endregion

#region favorite functions

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
    try{ $Ping = Test-Connection -ComputerName $Computer -Count 1 -ErrorAction SilentlyContinue -Quiet }
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
Set-Alias -Name ds -Value Get-DiskSpaceFormatted

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

function Test-Administrator{  
    $user = [Security.Principal.WindowsIdentity]::GetCurrent()
    (New-Object Security.Principal.WindowsPrincipal $user).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)  
}

function Start-PsElevatedSession{ 
    #Open a new elevated powershell window
    If( ! (Test-Administrator) ){
        if( $host.name -match 'ISE' ) { start-process PowerShell_ISE.exe -Verb runas }
        Else{ start-process powershell -Verb runas }
    }
    Else{ Write-Warning "Session is already elevated" }
} 
Set-alias -name su -Value Start-PsElevatedSession

function Get-ClipboardText(){
    Add-Type -AssemblyName System.Windows.Forms
    $tb = New-Object System.Windows.Forms.TextBox
    $tb.Multiline = $true
    $tb.Paste()
    ($tb.Text).trim()
} #END Get-ClipboardText
Set-Alias -Name clip -Value Get-ClipboardText 

function Find-StringInFile{
    Param(
    [Parameter(Mandatory=$true,Position=0)][string]$glob,
    [Parameter(Mandatory=$false,Position=1)][String]$path,
    [Parameter(Mandatory=$false)][Alias("r")][switch]$Recurse
    )
     
    If( $Recurse ) {get-childitem $path -recurse | select-string -pattern $glob | group path | select name } 
    Else {get-childitem $path | select-string -pattern $glob | group path | select name }     
}
Set-Alias -name fs -value Find-StringInFile

Function Start-Explorer{
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$False,Position=0)][ValidateScript({Test-Path $_})]$Path= '.'
    )
    Explorer $path
}
Set-Alias -Name Exp -Value Start-Explorer

#General helper functions
function Find-Files ([string] $glob) { get-childitem -recurse -include $glob }
Set-Alias -Name ff -Value Find-Files 

function Remove-Directory ([string] $glob) { remove-item -recurse -force $glob }
Set-Alias -Name rmd -value Remove-Directory 

function get-identity { (get-content env:\userdomain) + "\" + (get-content env:\username); }
Set-alias -name whoami -Value Get-Identity 

function Remove-FileExtention ([string] $filename) { [system.io.path]::getfilenamewithoutextension($filename) } 
Set-Alias -name stripext -value Remove-FileExtention 

#endregion

#region custom aliases

Set-Alias -name np -value "C:\Windows\System32\notepad.exe"  | out-null
Set-Alias -name npp -value "C:\Program Files (x86)\Notepad++\notepad++.exe"  | out-null
Set-Alias -name pss -value Enter-PsSession  | out-null
Set-Alias -name ih -value invoke-history

#endregion


export-modulemember -function * -variable * -alias * -Cmdlet * 