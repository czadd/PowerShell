<#
.Synopsis
   Send an email notification when a service account is locked out.
#>

Workflow Get-LockedSvcAcct{
    Param(
    [Parameter(Mandatory=$false)][String]$Account = 'svcacct01,svcacct02,svcacct03,svcacct04',
    [Parameter(Mandatory=$false)][String]$To = 'sysadmins@czadd.com',
    [Parameter(Mandatory=$false)][String]$From = 'SMAnotify@czadd.com',
    [Parameter(Mandatory=$false)][String]$SmtpServer = 'smtp.corp.czadd',
    [Parameter(Mandatory=$false)][String]$Subject = 'Service account locked out',
    [Parameter(Mandatory=$false)][String]$SMACred = 'Domain RO'
    )
    
    $AccountList = $Account -split ','
    $AccountList = $accountlist | foreach{ $_.trim() }

    #$Cred = Get-AutomationPSCredential -Name $SMACred 
    #$InlineScriptCred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $Cred.UserName, $Cred.Password

    $Flag = Get-SmaVariable -Name LockedSvcAcct -ErrorAction SilentlyContinue -WebServiceEndpoint https://sma.corp.czadd
    If( $Flag ){ 
        $Flags = (($Flag.Value).Split(';'))
    }

    Foreach( $a in $AccountList ){
        $User = Get-aduser $a -properties lockedout,AccountLockoutTime,Description

        If( $User.Lockedout ){
            Write-Verbose "Account locked out: $($User.SamAccountName)"
            Write-Output "Account Locked out: $($User |Select samaccountname, name, lockedout, AccountLockoutTime | Fl| Out-String)"
            $Body = "Service account locked out.`n`n"
            $Body += "SamAccountName:`t$($User.SamAccountName)`n"
            $Body += "AccountLockoutTime:`t$($User.AccountLockoutTime)`n"
            $Body += "Name:`t$($User.Name)`n"
            $Body += "Description:`t$($User.Description)`n"
            Send-MailMessage -SmtpServer $SmtpServer -To $To -From $From -Subject $Subject -Body $Body -Priority High
            If( $Flags.count -gt 0 ){ 
                Write-Verbose "Adding $($User.SamAccountName) to existing flag"
                Set-SmaVariable -Name LockedSvcAcct -Value "$($Flag.Value);'$(get-date) $($User.SamAccountName)" -WebServiceEndpoint https://sma.corp.czadd   
            }
            Else{
                Write-Verbose "Adding $($User.SamAccountName) (new) to flag"
                Set-SmaVariable -Name LockedSvcAcct -Value "$(get-date) $($User.SamAccountName)" -WebServiceEndpoint https://sma.corp.czadd   
            }
                     
        }
        Else{
            Write-Verbose "$($User.SamAccountName) Not locked out" 
            If( $Flags.count -gt 0 ){
                Write-Verbose "Removing $($User.SamAccountName) from flag"
                If( $Flags | Where{ $_ -notmatch $user.SamAccountName} ){ 
                    $NewFlags = ($Flags | Where{ $_ -notmatch $user.SamAccountName}) -join ";"
                    Set-SmaVariable -Name LockedSvcAcct -Value $newflags -WebServiceEndpoint https://sma.corp.czadd            
                }
            }
        }

    }
    
}



#  Get-LockedSvcAcct -to chad.smith@czadd.com -Account 'jdoe'
#  $JobId = Start-SmaRunbook -Name Get-LockedSvcAcct -WebServiceEndpoint $smaweb -Parameters @{To='chad.smith@czadd.com';Account='ejroe,jdoe'}
#  Get-SmaJob -Id $JobId -WebServiceEndpoint $smaweb 
#  Get-SmaJobOutput -Id $JobId -Stream Output -WebServiceEndpoint $smaweb 
