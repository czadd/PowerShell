<#
.SYNOPSIS
   This script enables JEA allowing restart of the Acronis service. 
.DESCRIPTION
   This script enables JEA allowing restart of the Acronis service. It allows members of the czadd\AppEditors group to restart the Acronis service. Run this script directly on the server to configure.
.EXAMPLE
   PS:> Enable-JeaAcronis.ps1
   Run it
.NOTES
   Csmith 10/1/2019
#>
#Requires -RunAsAdministrator 

[CmdletBinding()] 
Param(
    # ParamName help description. 
    [Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true,Position=0)][String]$ParamName
)

If( -not (Test-path 'C:\Program Files\WindowsPowerShell\ExtremeZ-IP_conf.pssc') ){
    Write-Host 'Copying PSRole capability (psrc) file.'
    If( -not (Test-Path '\\corp.czadd\share\ExtremeZ-IP_conf.pssc') ){ Throw "Cannot access the file '\\corp.czadd\share\JEA\ExtremeZ-IP_conf.pssc'" }
    Else{ Copy-Item '\\corp.czadd\share\JEA\ExtremeZ-IP_conf.pssc' 'C:\Program Files\WindowsPowerShell\ExtremeZ-IP_conf.pssc' }
}
Else{ Write-Warning 'PSRole capability file (psrc) exists.' }

If( -not (Get-PSSessionConfiguration -Name ExtremeZ-IP_admins -ErrorAction SilentlyContinue) ){
    Write-Host 'Registering PSSession configuration.'
    Register-PSSessionConfiguration -Name ExtremeZ-IP_admin -Path 'C:\Program Files\WindowsPowerShell\ExtremeZ-IP_conf.pssc'
    Restart-Service WinRm
}

$Config = Get-PSSessionConfiguration -Name ExtremeZ-IP_admin -ErrorAction SilentlyContinue

If( $Config ){ 
    Write-Host "Configuration registered successfully" 
    $Config
}
Else{ Throw "Unable to configure." }
