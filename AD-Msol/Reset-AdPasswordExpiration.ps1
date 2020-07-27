<#
.SYNOPSIS
   This script resets a user's password expiration date.
.DESCRIPTION
   This script extends a user's password expiration date. It can be used for single or multiple users. An email is sent to sysadmins when the script is executed. By default, the script uses SMTP relay. If you are on a computer that isn't allowed to relay (i.e. a laptop), use -Mailtype Outloook to send the email via outlook instead.
.EXAMPLE
   PS:> Reset-AdPasswordExpiration.ps1 
   Prompts for user(s) to reset
.EXAMPLE
   PS:> Reset-AdPasswordExpiration.ps1 -SamAccountName jdoe -MailType Outlook
   Resets the password expiration for jdoe and uses Outlook to send the email.
.EXAMPLE
   PS:> Reset-AdPasswordExpiration.ps1 jdoe
   Resets the password expiration date for the jdoe user
.EXAMPLE
   PS:> Reset-AdPasswordExpiration.ps1 -SamAccountName 'jdoe','bsmith'
   Resets the password expiration dates for jdoe and bsmith.
.EXAMPLE
   PS:> get-content list.txt | Reset-AdPasswordExpiration.ps1
   Ingests a list of users from the list.txt file (1 samaccountname per line) and resets all their password expiration dates. A digest is emailed to sysadmins.
.NOTES
   John Doe 1/1/2020
#>
#Requires -modules ActiveDirectory

[Cmdletbinding()]
Param( 
    # SamAccountName
    [Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true,Position=0)][Alias('name','User','UserName')][String[]]$SamAccountName,
    [Parameter(Mandatory=$false,ValueFromPipelineByPropertyName=$false)][Switch]$CheckOnly,
    [Parameter(Mandatory=$false,ValueFromPipelineByPropertyName=$false)][Validateset('SmtpRelay','Outlook')][String]$MailType = 'SmtpRelay'
)


Function Test-Aduser ($ADUserName) {
    Try{ If( Get-Aduser $ADUserName -ErrorAction SilentlyContinue) {$true} }
    Catch{ $false}
}


#Do it
$Result = Foreach( $UserName in $SamAccountName ){
    If( -not $CheckOnly ){ 
        If( Test-Aduser $UserName ){
            get-aduser $Username | set-aduser -ChangePasswordAtLogon $true | Out-null
            get-aduser $UserName | set-aduser -ChangePasswordAtLogon $false | Out-null
            Get-Aduser $UserName -Properties PasswordLastSet,PasswordExpired,LastLogonDate,LastBadPasswordAttempt | Select SamAccountName,Name,PasswordLastSet,LastLogonDate,LastBadPasswordAttempt,PasswordExpired
        }
        Else{ Write-Warning "$($UserName) Not found." }
    }
    
}

If( $Result) {
    $Result | Ft -AutoSize

    $Title = 'Password expiration extended'
    $Header = @"
    <style>
        TABLE {border-width: 1px;border-style: solid;border-color: black;border-collapse: collapse;}
        TH {border-width: 1px;padding: 3px;border-style: solid;border-color: black;background-color: #6495ED;}
        TD {border-width: 1px;padding: 3px;border-style: solid;border-color: black;}
    </style>
    <p>The password expiration date has been extended 90 days for the following user(s):</p>
"@
    $Footer = "<footer><p>Generated from $($Env:COMPUTERNAME.tolower()) by $($Env:Username) on $( (get-date).tostring() )</p></footer>"

    $Body = ($Result | ConvertTo-Html -Head $Header -Title $Title ) + $Footer | Out-String

    If( $Mailtype = 'SmtpRelay' ){ 
        Write-Verbose 'Using SMTP relay to send mail notification.'
        Send-MailMessage -SmtpServer smtp -To sysadmins@czadd.com -From noreply@czaddm.com -Subject 'Password expiration extended' -BodyAsHtml $Body 
    }
    Else{
        Write-Verbose 'Using Outlook to send mail notification.'
        Try{
            $Outlook = New-Object -ComObject Outlook.Application
            $Mail = $Outlook.CreateItem(0)
            $Mail.To = "sysadmins@czadd.com"
            $Mail.Subject = 'Password expiration extended'
            $Mail.Body = $Result
            $Mail.Send()
        }
        Catch{
            Write-error $Error[0]
        }

        [System.Runtime.Interopservices.Marshal]::ReleaseComObject($Outlook) | Out-Null
        $Outlook = $null
    }
}
Else{
    Else{ Write-Warning "$($UserName) Not found." }
}
