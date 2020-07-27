<#
.SYNOPSIS
   This script restarts the ExtremeZ-IP (Acronis AFP provider) service by connecting to a JEA endpoint.
.DESCRIPTION
   This script restarts the ExtremeZ-IP (Acronis AFP provider) service by connecting to a JEA endpoint.

.EXAMPLE
   PS:> Restart-Afs.ps1
   Restarts the ExtremeZ-IP service. The -ServiceName parameter can be used to target a different service.
.NOTES
   Csmith 6/29/2018
#>

[CmdletBinding()] 
Param(
    # Name of service. 
    [Parameter(Mandatory=$false,Position=0)][String]$ServiceName = 'ExtremeZ-IP',
    # Computer name. 
    [Parameter(Mandatory=$true)][ValidateSet ('AFS01','AFS02','AFS03')][String]$ComputerName,
    # Configuration name (JEA). 
    [Parameter(Mandatory=$false)][String]$ConfiguratioName = 'ExtremeZ-IP'
)

$Cred = Get-Credential
#$Cred = Import-Clixml C:\admintools\testcred.xml
Write-Host "Restarting $($ServiceName) Service on $($ComputerName)" -ForegroundColor Cyan
Try{ $Session = New-PSSession -ComputerName $ComputerName -Credential $Cred -ConfigurationName $ConfiguratioName -ErrorAction Stop }
Catch{ 
    Write-Error $_.Exception.Message
    Read-Host 'Press any key to exit'
    if( $Session) { $Session | Remove-PSSession }
    Break
}
Invoke-Command -Session $Session -ScriptBlock { Stop-service $USING:ServiceName -Passthru }
Start-Sleep -Seconds 3
$Svc = Invoke-Command -Session $Session -ScriptBlock { Get-service $USING:Servicename }
If( $Svc.Status -ne 'Stopped'){ Throw "$($ServiceName) not stopped" }
Else{ Invoke-Command -Session $Session -ScriptBlock { Start-Service $USING:ServiceName -Passthru } }

$Session | Remove-PSSession

Write-Host 
Read-Host 'Press any key to exit'