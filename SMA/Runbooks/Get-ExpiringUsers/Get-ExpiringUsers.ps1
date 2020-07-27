<#
.Synopsis
   Email a list of expiring temp users.
.DESCRIPTION
   Email a list of expiring temp users.
#>

Workflow Get-ExpiringUsers{
    Param(
    [Parameter(Mandatory=$false)][Int]$Days = 7,
    [Parameter(Mandatory=$false)][String]$To = 'sysadmins@czadd.com',
    [Parameter(Mandatory=$false)][String]$From = 'noreply@czadd.com',
    [Parameter(Mandatory=$false)][String]$SMTPServer = 'smtp.corp.czadd',
    [Parameter(Mandatory=$false)][String]$DomainController = 'dc01',
    [Parameter(Mandatory=$false)][String]$SMACred = 'Domain Join'
    )
    
    $Cred = Get-AutomationPSCredential -Name $SMACred 
    $InlineScriptCred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $Cred.UserName, $Cred.Password
    
    $Body = InlineScript {
        Import-Module ActiveDirectory
        $TempUserList = get-aduser -SearchBase 'OU=Temp Accounts,OU=NCM Users,DC=corp,DC=czadd' -Filter 'Enabled -eq "True" ' -Properties AccountExpirationDate,Manager
        $ExpiringUser = $TempUserList | Where { ($_.AccountExpirationDate - (get-date)).days -lt $USING:Days } | Select Name, SamAccountName,AccountExpirationDate,Enabled,@{l='Manager';e={get-aduser $_.Manager | Select -ExpandProperty SamAccountName} },Description 
        If( $ExpiringUser.count -gt 0 ){
            $Title = "Accounts Expiring within $(($USING:Days).tostring()) days"
            $Header = @"
                <style>
                    TABLE {border-width: 1px;border-style: solid;border-color: black;border-collapse: collapse;}
                    TH {border-width: 1px;padding: 3px;border-style: solid;border-color: black;background-color: #6495ED;}
                    TD {border-width: 1px;padding: 3px;border-style: solid;border-color: black;}
                </style>
                <H3>$Title</H3>
"@
            $Body = ''
            $Body += $ExpiringUser | ConvertTo-Html -Head $header -Title 'Expiring User Accounts'
            $Body
        }
    } -PSComputerName $DomainController -PSCredential $InlineScriptCred

    $Subject = "Accounts Expiring within $($Days.Tostring()) days"
    If( $Body ){
        Send-MailMessage -Body $Body -BodyAsHtml -Subject $Subject -To $To -From $From -SmtpServer $SMTPServer 
    }
    Else{ Write-Output "No users expiring within $days days" }
} 

#  Get-ExpiringUsers -to chad.smith@czadd.com -days 17 
#  $JobId = Start-SmaRunbook -Name Get-ExpiringUsers -WebServiceEndpoint $smaweb -Parameters @{Days=7;To='chad.smith@czadd.com'}
#  Get-SmaJob -Id $JobId -WebServiceEndpoint $smaweb 
#  Get-SmaJobOutput -Id $JobId -Stream Output -WebServiceEndpoint $smaweb