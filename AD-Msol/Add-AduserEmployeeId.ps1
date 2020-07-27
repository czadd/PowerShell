<#
.SYNOPSIS
   This script does something.
.DESCRIPTION
   This is a detailed description of the script.
.EXAMPLE
   PS:> ThisScript.ps1
   Example of how to use this cmdlet
.NOTES
   John Doe 1/1/2020
#>
#Requires -modules ActiveDirectory,ImportExcel

[CmdletBinding()] 
Param(
    # ParamName help description. 
    [Parameter(Mandatory=$false)]  [ValidateScript({test-path $_})]  [String]$InputFile = 'D:\ActiveEmployees.xlsx',
    [Parameter(Mandatory=$false)] [String]$Worksheet = 'Page1',
    [Parameter(Mandatory=$false)] [Switch]$Report,
    [Parameter(Mandatory=$false)] [Switch]$Force = $true
)

$AdUser = get-aduser -SearchBase 'ou=users,dc=corp,dc=czadd' -Filter ' employeeid -notlike "*" ' -Properties EmployeeId,Description,Notes,info,created,mail | where Distinguishedname -notmatch 'Temp Accounts'

If( $InputFile ){
    Write-Host "Importing spreadsheet $InputFile..."
    $EmployeeList = Import-Excel -Path $InputFile -WorksheetName $Worksheet -TopRow 4 | Where { $_.'Employee Number' -and $_.'Employee Type' -ne 'Temporary' }
    Foreach( $User in $AdUser ){
        $Employee = $EmployeeList | Where { $_.'Email Address' -match $User.Mail} 
        If( $Employee) {
            If( $Force ){ $yn = 'y' }
            Else{ Do{ $yn = Read-Host "$($User.Name) ($($User.SamAccountName)) $($Employee.'Employee Number'.Trim()). Set EmployeeID [y/n]?" } until( $yn -match '[yn]' ) }
            If( $yn -match 'y' ){
                
                $User | Set-ADUser -EmployeeID $Employee.'Employee Number'.Trim() 
                Get-Aduser $User | Select Name, SamAccountName, Mail, EmployeeId
            }
            Else{ Write-Warning "Skipping $($User.SamAccountName)." }
        }
        Else{ Write-Warning "Skipping $($User.SamAccountName). No matching email address found." }
    }
}
Else{
    $Aduser | Foreach{
        $_ | ft name, samaccountname, created, description, EmployeeId, info, distinguishedname -AutoSize
            $Eid = Read-host "Text for Employee ID"
            If( $Eid ){ $_ | set-aduser -employeeid $Eid -WhatIf}
            Else{ Write-Warning "Skipping $($_.Samaccountname)" }
    }
}