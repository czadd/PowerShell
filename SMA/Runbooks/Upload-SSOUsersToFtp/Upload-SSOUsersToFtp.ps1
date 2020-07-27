<#
.Synopsis
   Upload SSO users SMA workflow.
.DESCRIPTION
   Get users from AD, save to CSV, and FTP to TerryBerry.
.EXAMPLE
   Upload-SSoUsersToFtp -ADGroup 'SSO Users' -DomainController 'dc01' -ADCredential 'Domain RO' -emailnotifyAddress 'chad.smith@czadd.com' -path '\\corp.czadd\shares\Temp\SSO FTP' -FtpConnection 'FtpConn01' -Verbose
#>

Workflow Upload-SSOUsersToFtp{
#region Params and Preloads    
    Param(
        # Group containing SSO users
        [Parameter(Mandatory=$true)][String]$ADGroup,
        # Domain controller to run script against
        [Parameter(Mandatory=$true)][String]$DomainController,
        # Local credential to access AD
        [Parameter(Mandatory=$true)][String]$ADCredential,
        # FTP connection (this is an SMA connection object)
        [Parameter(Mandatory=$true)][String]$FtpConnection,
        # Path to save csv file so it can be uploaded
        [Parameter(Mandatory=$true)][String]$Path,
        # User or group to notify on failure
        [Parameter(Mandatory=$true)][String]$EmailNotifyAddress
    )

    $enddate = (Get-Date).tostring("yyyyMMdd")
    $filename = $enddate + '_Upload.csv'
    $FilePath = Join-Path $Path $filename
    $Subj = 'SSO User Upload'
    $EmailFrom = 'SMARunbookStatus@czadd.com'

    $FtpConn = Get-AutomationConnection -Name $FtpConnection 
    $InlineScriptCred = Get-AutomationPSCredential -Name $ADCredential
#endregion Params and Preloads

#region Prechecks
    If( -not ( Test-Connection -ComputerName $DomainController -Quiet ) ){ 
        $Body = "Error: Cannot connect to $DomainController"
        Send-MailMessage -SmtpServer smtp -Subject "$Subj Failed" -Body $body -to $EmailNotifyAddress -from $EmailFrom        
        Write-Output $Body -ErrorAction Stop
    }
#endregion Prechecks

#region Export from AD to CSV
    $FTPUserListErr = Inlinescript{
        $VerbosePreference = [System.Management.Automation.ActionPreference]$USING:VerbosePreference
        $DebugPreference = [System.Management.Automation.ActionPreference]$USING:DebugPreference 

        Function Remove-DeptNum ([String]$DeptName){
            $DeptName.split('-',2)[1].trim()
        }

        If( -Not (Test-path $USING:Path) ){
            $Err = "Error: Path not found: $USING:Path" 
            Write-error $Err
            $Err
            Exit
        }
        Write-Verbose "Path: $USING:Path"

        Import-Module ActiveDirectory -Verbose:$false

        Try{ $ADUserList = Get-ADUser -LdapFilter "(&(!useraccountcontrol:1.2.840.113556.1.4.803:=2)(memberof=$(Get-ADGroup 'all employees')))" -searchbase 'ou=users,dc=corp,dc=czadd' -Properties emailaddress,title,employeeid,department,office,extensionAttribute1,extensionAttribute2,extensionAttribute5,extensionAttribute6,extensionAttribute7,streetaddress,state,city,postalcode,country,manager | Where { ($_.EmployeeId) -and ($_.Employeeid -notlike 'Contractor') -and ($_.Employeeid -notlike 'ServiceAccount') -and ($_.Employeeid -notlike '*Temp*') -and ($_.Employeeid -notlike '*Promo*') } | select givenname,name,surname,samaccountname,emailaddress,title,employeeid,department,office,extensionAttribute1,extensionAttribute2,extensionAttribute5,extensionAttribute6,extensionAttribute7,streetaddress,state,city,postalcode,country,userprincipalname,manager }
        Catch{ 
            $Err = "Error: "+ $_.Exception
            Write-Verbose $Err
            $Err
            Exit
        }
        Write-Verbose "User count: $($AduserList.count)"

        $AdUserlistObject = $AdUserList | foreach-object{
            new-object psobject -Property @{
	            'First name' = $_.givenname
	            'Preferred name' = ''
	            'Last name' = $_.surname
	            'UserName' = $_.userprincipalname
	            'Employee email Address' = $_.emailaddress
	            'Job Title' = $_.title
	            'Employee ID' = $_.employeeid
	            'Department' = Remove-DeptNum $_.department
	            'Location' = $_.state.trim()
                'supervisor ID' = (get-aduser $_.manager -Properties employeeid).employeeid
                #'supervisor ID' = (get-aduser (get-aduser $_.SamAccountName -Properties manager).manager).employeeid

	        }
        }

        Try{ $AdUserlistObject | Select 'First name','Preferred name','Last name',UserName,'Employee email Address','Job Title','Employee ID','Department','Location','supervisor ID' | export-csv -Path $USING:filepath -Confirm:$false -NoTypeInformation -force }
        Catch{ 
            $err = "Error: " + $_.Exception 
            $err
            Write-Verbose $err
            Exit
        }

        Write-Verbose "Exported $($AdUserlistObject.count) users to $($USING:Filepath)"

    } -PSComputerName $DomainController -PSCredential $InlineScriptCred
    

    If( $FTPUserListErr ){ #If we get anything here, then there was an error
        $Body = "Error exporting SSO user list.`n`n" + $FTPUserListErr
        Send-MailMessage -SmtpServer smtp -Subject "$Subj Failed" -Body $body -to $EmailNotifyAddress -from $EmailFrom
        Write-Error $FTPUserListErr
        $FTPUserListErr
        exit
    }
    Else{ 
        Write-Verbose "Exported $FilePath"
    }
#endregion Export from AD to CSV

#region FTP upload
    $FtpUploadErr = Inlinescript{
        $VerbosePreference = [System.Management.Automation.ActionPreference]$USING:VerbosePreference
        $DebugPreference = [System.Management.Automation.ActionPreference]$USING:DebugPreference 

        If( -Not (Test-path $USING:FilePath -ErrorAction silentlycontinue) ){
            $Err = "Error: Path not found. $USING:FilePath" 
            Write-error $Err
            $Err
            Exit
        }
        Else{ Write-Verbose "FilePath: $USING:FilePath" }

        $SecurePassword = ConvertTo-SecureString -AsPlainText -String $USING:FtpConn.Password -Force

        $webclient = New-Object System.Net.WebClient
        $webclient.Credentials = New-Object System.Net.NetworkCredential($USING:FtpConn.UserName,$USING:FtpConn.Password)
        
        $uri = New-Object System.Uri('FTP://' + $USING:FtpConn.FTPServer + '/' + (Split-Path $USING:FilePath -Leaf)) 
        Write-Verbose $Uri

        Write-Verbose "FTP uri: $($uri.OriginalString)"

        $UploadErr = 
            Try{ $webclient.UploadFile($uri, $USING:Filepath) }
            Catch [System.Net.Webexception]{ $_ }

        If( -not $Uploaderr ){ 
            Write-Verbose "Upload successful."
            $Err = "Upload Successful." 
            $UploadVerifyErr = 
                Try{ 
                    $Filename = Join-path $env:temp "$([guid]::newguid()).csv"
                    $webclient.DownloadFile($uri,$Filename)
                }
                Catch [System.Net.WebException]{ $_.Exception }
            If( -not $UploadVerifyErr ){ 
                Write-Verbose "Upload verified." 
                $Err = $Err + " Upload Verified."
            }
            Else{ 
                Write-Verbose "Upload verification failed." 
                $Err = "Error: " + $Err + " Upload verification failed."
            }
        }
        Else{ 
            Write-Verbose "Upload failed."
            $Err = "Error: Upload failed."
        }
        Write-Verbose $err
        Write-Output $Err

    } -PSComputerName $DomainController -PSCredential $InlineScriptCred

    If( $FtpUploadErr -like "Error:*" ){
        $Body = "Error uploading TerryBerry user list.`n`n" + $FtpUploadErr
        Send-MailMessage -SmtpServer smtp -Subject "$Subj Failed" -Body $body -to $EmailNotifyAddress -from $EmailFrom
        Write-Error $FtpUploadErr
        $FtpUploadErr
    }
    Else{
        $Body = "Uploaded TerryBerry user list.`n`n" + $FtpUploadErr
        #Send-MailMessage -SmtpServer smtp -Subject "$Subj Success" -Body $body -to $EmailNotifyAddress -from $EmailFrom
    }

#endregion FTP upload

}

#  Upload-TerryBerryUsers -ADGroup 'TerryBerry Users' -DomainController 'prd-dc01-den' -ADCredential 'Domain Join' -emailnotifyAddress 'chad.smith@ncm.com' -path '\\corporate.ncm\groupshares\IT\SysAdmins\Temp\TerryBerry FTP' -FtpConnection 'TerryBerry FTP' -Verbose
#  $JobId = Start-SmaRunbook -Name Upload-TerryBerryUsers -Parameters  @{ADGroup='NCM All Employees';DomainController='ncmpdcden01';ADCredential='Domain Join';emailnotifyAddress='sysadmins@ncm.com';path='\\corporate.ncm\groupshares\IT\SysAdmins\Temp\TerryBerry FTP';FtpConnection='Terryberry FTP'} -WebServiceEndpoint $smaweb
#  Get-SmaJob -Id $JobId -WebServiceEndpoint $smaweb 
#  Get-SmaJobOutput -Id $JobId -Stream Output -WebServiceEndpoint $smaweb
