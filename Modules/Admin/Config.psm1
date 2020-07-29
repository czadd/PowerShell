##########################################################################################
# Configuration params
##########################################################################################

### Set up some global functions that will be used while setting up the profile ###

Function Add-ToPath {
    Param(
        [Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true,Position=0)][ValidateNotNull()][String]$NewDir
    )
    $Path = $env:path -split ';'
    If( $path -notcontains $NewDir ){
        If( $Env:path.Substring($env:path.Length -1,1) -eq ';' ){
            $Env:Path = $Env:Path + $NewDir + ';'
        }
        Else{
            $Env:Path = $Env:Path + ';' + $NewDir + ';'
        }
    }
}

### Set up some global variables and paths ###
$user = [Environment]::UserName
$ModulePath = "c:\repo\czadd\Modules"
If( $env:psmodulepath -notlike "*;$ModulePath;*" ){ $env:psmodulepath = $env:psmodulepath +";" + $ModulePath }
set-item -path env:HOME -value (get-item ([environment]::GetFolderPath("MyDocuments"))).Parent.FullName

$Filesystem = Get-PSProvider filesystem
$Filesystem.Home = $env:HOME

#Set up global params for alias help
$Global:AdminHelp = {}
$Global:AdminHelp = @()

#Default values for cmdlets
$PSDefaultParameterValues = @{
    "get-aduser:Properties"="description","office","OfficePhone","msRTCSIP-PrimaryUserAddress","msRTCSIP-Line","MobilePhone","Description","AccountLockoutTime","extensionattribute1","EmployeeId","Department";
    "Send-MailMessage:SMTPServer" = "smtp.corp.czadd";
    "get-ciminstance:ClassName"   = "Win32_ComputerSystem";
}

#Make a variable for my personal creds
$CredPath = Join-path $env:appdata "msolcred.xml"
If( Test-Path $CredPath){ $MC = Import-Clixml $CredPath }

#Add personal powershel modules paths
Add-ToPath (Join-Path ([environment]::GetFolderPath("MyDocuments")) "WindowsPowerShell")
Add-ToPath (Join-Path ([environment]::GetFolderPath("MyDocuments")) "WindowsPowerShell\Modules")

export-modulemember -function * -variable * -alias * -Cmdlet * 
