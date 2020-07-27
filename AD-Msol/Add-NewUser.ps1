 <#
 .Synopsis
    Add new user. 
 .DESCRIPTION
    Add new user to AD and set up MSOL licensing and mailbox.
 .EXAMPLE
    PS:> O365 New User.ps1
    Script will prompt for user to add
 #>
#Requires -modules ActiveDirectory 

[CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact="High",DefaultParameterSetName='PromptUser')]
Param(
    #New user's first name
    [Parameter(Mandatory=$True, ValueFromPipelineByPropertyName=$true,ParameterSetName='NoUserPrompt')][String]$First,
    #New user's last name
    [Parameter(Mandatory=$True, ValueFromPipelineByPropertyName=$true,ParameterSetName='NoUserPrompt')][String]$Last,
    #New user's middle name or initial
    [Parameter(Mandatory=$False,ValueFromPipelineByPropertyName=$true,ParameterSetName='NoUserPrompt')][String]$Middle,
    #New user's name if different than the default: FirstName LastName
    [Parameter(Mandatory=$False,ValueFromPipelineByPropertyName=$true,ParameterSetName='NoUserPrompt')][String]$Name,
    #New user's display name if different from name. E.g. name is Robert Smith, but he goes by Bob Smith
    [Parameter(Mandatory=$False,ValueFromPipelineByPropertyName=$true,ParameterSetName='NoUserPrompt')][String]$DisplayName,
    #New user's title
    [Parameter(Mandatory=$True, ValueFromPipelineByPropertyName=$true,ParameterSetName='NoUserPrompt')][String]$Title,
    #New user's description. Usually left blank.
    [Parameter(Mandatory=$False,ValueFromPipelineByPropertyName=$true,ParameterSetName='NoUserPrompt')][String]$Description,
    #New user's SamAccountName if different from the default of first initial, last name
    [Parameter(Mandatory=$False,ValueFromPipelineByPropertyName=$true,ParameterSetName='NoUserPrompt')][String]$SamAccountName,
    #UserPrincipalName if different from the default of samaccountname@myco.com
    [Parameter(Mandatory=$False,ValueFromPipelineByPropertyName=$true,ParameterSetName='NoUserPrompt')][String][ValidateScript({$_ -match "[A-Za-z]+@myco\.com$"})]$UserPrincipalName,
    #Email address if different from the default of first.last@myco.com
    [Parameter(Mandatory=$False,ValueFromPipelineByPropertyName=$true,ParameterSetName='NoUserPrompt')][String][ValidateScript({$_ -match "[A-Za-z]+\.[A-Za-z]+@myco\.com$"})]$EmailAddress,
    #Copyaddress will copy the street address, PO box, City, State, and zip from the "UserToCopy" user
    [Parameter(Mandatory=$False,ValueFromPipelineByPropertyName=$true,ParameterSetName='NoUserPrompt')][Switch]$CopyAddress,
    #Street address first line
    [Parameter(Mandatory=$False,ValueFromPipelineByPropertyName=$true,ParameterSetName='NoUserPrompt')][String]$StreetAddress1,
    #Street address second line
    [Parameter(Mandatory=$False,ValueFromPipelineByPropertyName=$true,ParameterSetName='NoUserPrompt')][String]$StreetAddress2,
    #Street address third (last) line
    [Parameter(Mandatory=$False,ValueFromPipelineByPropertyName=$true,ParameterSetName='NoUserPrompt')][String]$StreetAddress3,
    #City
    [Parameter(Mandatory=$False,ValueFromPipelineByPropertyName=$true,ParameterSetName='NoUserPrompt')][String]$City,
    #State (2 letter abbreviation)
    [Parameter(Mandatory=$False,ValueFromPipelineByPropertyName=$true,ParameterSetName='NoUserPrompt')][String][ValidateScript({$_ -match "^[A-Za-z]{2}$"})]$State,
    #Postal code.  00000 or 00000-0000
    [Parameter(Mandatory=$False,ValueFromPipelineByPropertyName=$true,ParameterSetName='NoUserPrompt')][String][ValidateScript({$_ -match "^\d{5}(?:[-\s]\d{4})?$"})]$Zip,
    #Department if different from the UserToCopy user's department
    [Parameter(Mandatory=$False,ValueFromPipelineByPropertyName=$true,ParameterSetName='NoUserPrompt')][String]$Department,
    #Manager SamAccountName if different from the UserToCopy user's department
    [Parameter(Mandatory=$True, ValueFromPipelineByPropertyName=$true,ParameterSetName='NoUserPrompt')][String][ValidateScript({get-aduser $_})]$Manager,
    #Intercall (phone) number.  10 digits, no punctuation
    [Parameter(Mandatory=$False,ValueFromPipelineByPropertyName=$true,ParameterSetName='NoUserPrompt')][String][ValidateScript({$_ -match "^\d{10}$"})]$Intercall,
    #Home drive if different from default of H:
    [Parameter(Mandatory=$False,ValueFromPipelineByPropertyName=$true,ParameterSetName='NoUserPrompt')][String]$HomeDrive,
    #Home directory if different from default
    [Parameter(Mandatory=$False,ValueFromPipelineByPropertyName=$true,ParameterSetName='NoUserPrompt')][String]$HomeDirectory,
    #Use the FinanceUser switch to automatically set the new user's home directory to the finance path
    [Parameter(Mandatory=$False,ValueFromPipelineByPropertyName=$true,ParameterSetName='NoUserPrompt')][Switch]$FinanceUser,
    #Use the TempEmployee switch to set as temp. An end date will be required and the user will be removed from the myco All Employees group
    [Parameter(Mandatory=$False,ValueFromPipelineByPropertyName=$true,ParameterSetName='NoUserPrompt')][Switch]$TempEmployee,
    #EndDate is required for temporary or contract employees
    [Parameter(Mandatory=$False,ValueFromPipelineByPropertyName=$true,ParameterSetName='NoUserPrompt')][DateTime]$EndDate,
    #UserToCopy is the user to copy basic info such as company, department, manager, address from
    [Parameter(Mandatory=$False, ValueFromPipelineByPropertyName=$true)][String][ValidateScript({get-aduser $_ })]$UserToCopy,
    #Max wait time for sync with cloud resources
    [Parameter(Mandatory=$false,ValueFromPipelineByPropertyName=$true)][Int]$MaxWaitSeconds = 600,
    [Parameter(Mandatory=$false,ValueFromPipelineByPropertyName=$true)][Switch]$MFA
)

#region Functions
Function Test-CredentialObject{ 
    Param(
        # Credential object containing username and encrypted password
        [Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true,Position=0)][System.Management.Automation.PSCredential]$CredObject
    )
    Add-Type -AssemblyName System.DirectoryServices.AccountManagement
    $CT = [System.DirectoryServices.AccountManagement.ContextType]::Domain
    $PC = New-Object System.DirectoryServices.AccountManagement.PrincipalContext($CT)
    $PC.ValidateCredentials($Credobject.Username, [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($credobject.Password)))
}

function Get-ADParent ([string] $dn) {
     $parts = $dn -split '(?<![\\]),'
     $parts[1..$($parts.Count-1)] -join ','
}

Function Check-Aduser ($UserName) {
    Try{ If( Get-Aduser $UserName -ErrorAction SilentlyContinue) {$true} }
    Catch{ $false}
}

#function to find cloud-based DLs
function Find-CloudBasedGroupMembership ([string]$UserToSearch){
    $ADGroups = get-adprincipalgroupmembership $UserToSearch
    Get-DistributionGroup -ResultSize unlimited | Where { $_.name -in $ADGroups.name }
}

#function to generate a secure password
function New-Password{
    $Password = ""
    $SwitchRange = (1..4)
    $UpperRange = (65..90)
    $LowerRange = (97..122)
    $SymbolRange = (33..47)
    $NumberRange = (48..57)
    for($i=1; $i -le 20; $i++){
        if(($switchRange | get-random) -eq 1){$character=[char]($UpperRange | Get-Random); $Password = $Password + "$character"}
        if(($switchRange | get-random) -eq 2){$character=[char]($LowerRange | Get-Random); $Password = $Password + "$character"}
        if(($switchRange | get-random) -eq 3){$character=[char]($SymbolRange | Get-Random); $Password = $Password + "$character"}
        if(($switchRange | get-random) -eq 4){$character=[char]($NumberRange | Get-Random); $Password = $Password + "$character"}
    }
    $SecurePassword = ConvertTo-SecureString $Password -AsPlainText -Force
    return $SecurePassword
}
#endregion Functions


#region Get saved creds. Request new cred if invalid or missing.
$SavedCredPath = Join-Path $env:APPDATA 'MsolCred.xml' #Cred can be saved by executing: get-credential | export-clixml $env:APPDATA 'MsolCred.xml'
If( test-path $SavedCredPath ){ 
    $Cred = Import-Clixml $SavedCredPath 
    If( -not (Test-CredentialObject -CredObject $Cred) ){
        Write-Host -ForegroundColor Yellow "Saved credentials are invalid.  Please re-enter credential."
        Do{ 
            $Cred = Get-credential "$($env:USERDOMAIN)\$($env:USERNAME)" 
            $CredIsvalid = Test-CredentialObject $Cred
        }
        Until( $CredIsvalid  )
        $Cred | Export-Clixml $SavedCredPath
    }    
}
Else{ 
    Write-Host "Saved credential not found. Enter valid credential."
    Do{ $Cred = Get-credential "$($env:USERDOMAIN)\$($env:USERNAME)" }
    Until( Test-CredentialObject $cred  )
    $Cred | Export-Clixml $SavedCredPath
}
#endregion Get saved creds. Request new cred if invalid or missing.

#region Connect to Exchange O365
$Sku = Get-MsolAccountSku -ErrorAction SilentlyContinue
If( -not $Sku ){
    $O365Session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri https://ps.outlook.com/powershell/ -Credential $Cred -Authentication Basic -AllowRedirection
    Import-PSSession $O365session
    Connect-MsolService -Credential $cred
}
#endregion Connect to Exchange O365

#Get info of user to copy
If( -Not $UserToCopy ){ $UsertoCopy = Read-host "SamAccountName of user to copy (e.g. 'jdoe')"  }
If( Check-Aduser $UserToCopy ){ $Copied = get-aduser $UserToCopy -properties * }
Else{ Throw "User to copy `($($UserToCopy)`) is invalid." }

#region Gather user's info if we are in PromptUser mode
If( $PSCmdlet.ParameterSetName -eq 'PromptUser' ){ 

    $FirstName = Read-Host "New user's first name" | Foreach{ (Get-culture).TextInfo.ToTitleCase($_) } 
    $MiddleInitialName = Read-Host "New user's middle initial or middle name (press enter for none)" | Foreach{ (Get-culture).TextInfo.ToTitleCase($_) } 
    $LastName = Read-Host "New user's last name" | Foreach{ (Get-culture).TextInfo.ToTitleCase($_) } 

    if( $MiddleinitialName ){
        $Name = "$($FirstName) $($MiddleinitialName.Substring(0,1)). $($LastName)"
        $Mail = ("$($FirstName)$($MiddleinitialName.Substring(0,1)).$($Lastname)@myco.com").ToLower()
        $SamAccountName = ("$($Firstname.Substring(0,1))$($MiddleInitialName.Substring(0,1))$($LastName)").ToLower()
    }
    else{         
        $Name = "$FirstName $LastName"
        $SamAccountName = ("$($Firstname.Substring(0,1))$($LastName)").ToLower()
        $Mail = ("$($FirstName).$($Lastname)@myco.com").tolower()
    }
    $CustomSam = Read-Host "SamAccountName (Enter for `"$SamaccountName`")"
    If( $CustomSam ){ $SamAccountName = $CustomSam.ToLower() }

    $DisplayName = Read-Host "DisplayName (Enter for `"$($Name)`")"
    If( -not $Displayname ){ $DisplayName = $Name }
    $Displayname = $DisplayName | Foreach{ (Get-culture).TextInfo.ToTitleCase($_) } 

    [Regex]$MailFormat = "[A-Za-z]+\.[A-Za-z]+@myco\.com$"
    Do{ $CustomMail = Read-Host "Email address (Enter for $mail)" } Until( ($CustomMail -match $MailFormat) -or (-not $CustomMail) )
    If( $CustomMail ){ $Mail = $CustomMail }

    If( Check-Aduser $SamAccountName ){
        Write-Warning "SamAccountName $SamAccountName already exists. Please choose a new SamAccountName."
        Do{ $SamAccountName = Read-Host "New user's sAMAccount Name (e.g. 'jdoe')"}
        Until( -not (Check-Aduser $SamAccountName) )
    }
    $UPN = ("$SamAccountName@myco.com").ToLower()

    $Title = Read-Host "New user's title" 

    #request address
    If( $Copied.StreetAddress ){
        #Write-Host "Address copied from $($UsertoCopy):`n$($Copied.StreetAddress)`n$($Copied.City), $($Copied.St) $($Copied.PostalCode)"
        Do{ $CopyAddressYN = Read-Host "Use copied address?`n$($Copied.StreetAddress)`n$($Copied.City), $($Copied.St) $($Copied.PostalCode)`n(y/n)" } Until( $CopyAddressYN -match '[yn]' )
        If( $CopyAddressYn -match 'y' ){ 
            $StreetAddress = $Copied.StreetAddress 
            $City = $Copied.City
            $State = $Copied.St
            $Zip = $Copied.PostalCode
        }
        Else{
            $NewUserStreet1 = Read-Host "Street address line 1 (Enter for none)"
            if($NewUserStreet1.length -gt 0){
                $NewUserStreet2 = Read-Host "Street address line 2 (enter if none)"
                $NewUserStreet3 = Read-Host "Street address line 3 (enter if none)"
                $POBox = Read-Host "PO Box (enter if none)"
                $City = Read-Host "City (enter if no address)"
                Do{ $State = Read-Host "State (2 letter abbreviation; enter if no address)" } Until( $State -match "^[a-z,A-Z]{2}$" )
                $State = $State.ToUpper()
                Do{ $Zip = Read-Host "Zipcode (enter if none)" } Until( ($Zip -match "^\d{5}$") -or ($Zip -match "^\d{5}-\d{4}$") -or ($Zip -eq '') )
            }
            if($NewUserStreet2.length -eq 0){$StreetAddress = $NewUserStreet1}
            else{
                if($NewUserStreet3.length -eq 0){$StreetAddress = ($NewUserStreet1 + "`r`n" + $NewUserStreet2)}
                else{$StreetAddress = ($NewUserStreet1 + "`r`n" + $NewUserStreet2 + "`r`n" + $NewUserStreet3)}
            }
        }
    }

    #request additional information
    $Description = Read-Host "Description (enter for none)"
    Do{ $FinanceYn = Read-Host "Is this a finance user? (Y/N)?" } Until( $FinanceYN -match '[yn]' )
    Do{ $TempYn = Read-Host "Is this a temporary or contract user (Y/N)?" } Until( $TempYN -match '[yn]' )
    If( $TempYn -match 'y' ){ 
        $Exp = [DateTime]::Today.AddDays(90) 
        [regex]$DateFormat = "(\d{1,2})[/](\d{1,2})[/](\d{4})"
        Do{ $d = Read-Host "EndDate mm/dd/yyyy (Enter for $Exp)" } Until( ($d -match $DateFormat) -or (-not $d) )
        If( $d ){ $EndDate = Get-date $d }
        Else{ $EndDate = $exp }
    }

    $HomeDrive = 'H:'
    If( $FinanceYn -match 'n' ){ $HomeDirectory = ("\\corp.myco\user\home$\" + $SamAccountName);$HomeDirectoryLocation = "\\corp.myco\user\home$\"}
    Else{$HomeDirectory = ("\\corp.myco\finance\home$\" + $SamAccountName);$HomeDirectoryLocation = "\\corp.myco\finance\home$"}


    [regex]$digits="^\d{10}$"
    Do{ $Intercall = Read-Host "Intercall Reservationless Plus number from TCC online (10 digits, no punctuation). Enter to skip" }
    Until( ($Intercall -match $digits) -or $Intercall -eq '' )

}
#endregion Gather user's info if we are in PromptUser mode

#region Validate user info and populate params if not in PromptUser mode

#endregion Validate user info and populate params if not in PromptUser mode

#TODO: CHECK for exisiting samaccountname, upn, email

$NewUserObject = New-Object PsObject -Property @{
    'Department' = $copied.department
    'Company' = $copied.company
    'Manager' = get-aduser $copied.manager | select -ExpandProperty name
    'OU' = get-adparent $copied
    'PhysicalDeliveryOfficeName' = $copied.physicalDeliveryOfficeName
}

$NewUserObject | Add-Member -MemberType NoteProperty -Name 'SamAccountName' -Value $SamAccountName
$NewUserObject | Add-Member -MemberType NoteProperty -Name 'UserPrincipalName' -Value $UPN
$NewUserObject | Add-Member -MemberType NoteProperty -Name 'First' -Value $FirstName
$NewUserObject | Add-Member -MemberType NoteProperty -Name 'Last' -Value $LastName
$NewUserObject | Add-Member -MemberType NoteProperty -Name 'Middle' -Value $MiddleinitialName
$NewUserObject | Add-Member -MemberType NoteProperty -Name 'Name' -Value $Name
$NewUserObject | Add-Member -MemberType NoteProperty -Name 'DisplayName' -Value $DisplayName
$NewUserObject | Add-Member -MemberType NoteProperty -Name 'EmailAddress' -Value $Mail
$NewUserObject | Add-member -MemberType NoteProperty -Name 'Intercall' -Value $Intercall
$NewUserObject | Add-member -MemberType NoteProperty -Name 'Description' -Value $Description
$NewUserObject | Add-member -MemberType NoteProperty -Name 'StreetAddress' -Value $StreetAddress
$NewUserObject | Add-member -MemberType NoteProperty -Name 'POBox' -Value $POBox
$NewUserObject | Add-member -MemberType NoteProperty -Name 'City' -Value $City
$NewUserObject | Add-member -MemberType NoteProperty -Name 'State' -Value $State
$NewUserObject | Add-member -MemberType NoteProperty -Name 'Zip' -Value $Zip
$NewUserObject | Add-member -MemberType NoteProperty -Name 'HomeDrive' -Value $HomeDrive
$NewUserObject | Add-member -MemberType NoteProperty -Name 'HomeDirectory' -Value $HomeDirectory
$NewUserObject | Add-member -MemberType NoteProperty -Name 'FinanceUser' -Value $FinanceYN.Toupper()
$NewUserObject | Add-member -MemberType NoteProperty -Name 'TempEmployee' -Value $TempYN.ToUpper()
$NewUserObject | Add-member -MemberType NoteProperty -Name 'Title' -Value $Title
$NewUserObject | Add-member -MemberType NoteProperty -Name 'EndDate' -Value $EndDate
#$NewUserObject | Add-member -MemberType NoteProperty -Name '' -Value

$NewUserObject | Select First,Last,Middle,Name,Displayname,Title,Description,SamaccountName,UserPrincipalName,EmailAddress,Address,City,State,Zip,Company,Department,Manager,Intercall,HomeDrive,HomeDirectory,FinanceUser,TempEmployee,EndDate
#$pausevar = Read-Host "Is this what you want to create? (press enter if yes, ctrl+c if no)"
#If( -not $pscmdlet.ShouldContinue("First: $($NewUserObject.First)`nLast$($NewuserObject.Last)","Create user?") ){ exit }
If( -not $pscmdlet.ShouldContinue("
First: $($NewUserObject.First)
Last: $($NewuserObject.Last)
Middle: $($NewuserObject.Middle)
Name: $($NewuserObject.Name)
Displayname: $($NewuserObject.DisplayName)
Title: $($NewuserObject.Title)
Description: $($NewuserObject.Description)
SamaccountName: $($NewuserObject.SamAccountName)
UPN: $($NewuserObject.UserPrincipalName)
EmailAddress: $($NewuserObject.EmailAddress)
StreetAddress: $($NewuserObject.StreetAddress)
City: $($NewuserObject.City)
State: $($NewuserObject.State)
Zip: $($NewuserObject.Zip)
Company: $($NewuserObject.Company)
Department: $($NewuserObject.Department)
Manager: $($NewuserObject.Manager)
Intercall: $($NewuserObject.Intercall)
HomeDrive: $($NewuserObject.HomeDrive)
HomeDirectory: $($NewuserObject.HomeDirectory)
FinanceUser: $($NewuserObject.FinanceUser)
TempEmployee: $($NewuserObject.TempEmployee)
EndDate: $($NewuserObject.EndDate)

"
, "Create user?") ){ exit }
#create user
New-ADUser $NewUserObject.Name -Description $NewUserObject.Description -DisplayName $NewUserObject.displayName -City $NewUserObject.City -StreetAddress $NewUserObject.StreetAddress -PostalCode $NewUserObject.Zip -Country "US" -POBox $NewUserObject.POBox -State $NewUserObject.State -HomeDrive $NewUserObject.homeDrive -HomeDirectory $NewUserObject.homeDirectory -Title $NewUserObject.Title -Path $NewUserObject.OU -Manager $NewUserObject.Manager -SamAccountName $NewUserObject.SamAccountName -UserPrincipalName $NewUserObject.userPrincipalName -GivenName $NewUserObject.First -EmailAddress $NewUserObject.EmailAddress -Surname $NewUserObject.Last -Department $NewUserObject.department -Company $NewUserObject.company -Enabled $true -AccountPassword (New-Password($null)) -WhatIf
break
#wait for user object to show up
for($i = 0 ; $i -le 0; $i=$i){
    $ErrorActionPreference = "SilentlyContinue"
    if((Get-ADUser $NewUserObject.SamAccountName) -eq $null){write-host ".";Start-Sleep 2}
    else{$i++}
}

#create user's home drive and add permissions for user
New-Item -path $NewUserObject.HomeDirectory -Name $NewUserObject.SamAccountName -ItemType Directory

for($x = 0; $x -le 0; ){
    if((Get-Acl $NewUserObject.homeDirectory).access.identityreference.value -contains "myco\" + $NewUserObject.SamAccountName){$x++}
    else{
        $Rights= [System.Security.AccessControl.FileSystemRights]::Read -bor [System.Security.AccessControl.FileSystemRights]::Write -bor [System.Security.AccessControl.FileSystemRights]::Modify -bor [System.Security.AccessControl.FileSystemRights]::FullControl
        $Inherit=[System.Security.AccessControl.InheritanceFlags]::ContainerInherit -bor [System.Security.AccessControl.InheritanceFlags]::ObjectInherit
        $Propogation=[System.Security.AccessControl.PropagationFlags]::None
        $Access=[System.Security.AccessControl.AccessControlType]::Allow
        $AccessRule = new-object System.Security.AccessControl.FileSystemAccessRule($NewUserObject.userPrincipalName,$Rights,$Inherit,$Propogation,$Access)
        $ACL = Get-Acl $NewUserObject.homeDirectoryLocation
        $ACL.AddAccessRule($AccessRule)
        $Account = new-object system.security.principal.ntaccount($NewUserObject.userPrincipalName)
        $ACL.setowner($Account)
        $ACL.SetAccessRule($AccessRule)
        Set-Acl -path $NewUserObject.homeDirectory -AclObject $ACL
        write-host "Checking that H drive permissions are set correctly..."
        Start-Sleep -s 1
     }
}
 
#Populate extensionAttribute1 with the last name
Set-ADUser $SamAccountName -add @{extensionAttribute1=$NewUserObject.First} 

#explicitly define Exchange alias before syncing to cloud
Set-ADUser $SamAccountName -Replace @{mailNickname=$SamAccountName}

Write-Host "Waiting 60 seconds for AD changes to register" #I've found that changes don't sync unless we've waited a bit for AAD sync to pick it up. -CRS
Start-Sleep -Seconds 60

#Connect to mycoDIRSYNC and sync user to MSOL
$ADFSSession = New-PSSession -ComputerName SyncServer.coporate.myco -Credential $Cred -Authentication Kerberos
Invoke-Command -Session $ADFSSession -ScriptBlock {
    $SyncStatus = Get-ADSyncConnectorRunStatus
    If( $SyncStatus ){ Write-Host "AD Sync is already in progress." -NoNewline -ForegroundColor Yellow }
    Else{ 
        Write-host "Syncing." -NoNewline -ForegroundColor Green
        Start-ADSyncSyncCycle -PolicyType Delta
    }
    
    Do{
        Start-sleep -Seconds 3
        $SyncStatus = Get-ADSyncConnectorRunStatus
        Write-Host "."  -NoNewline
    }
    While ( $SyncStatus )
    Get-ADSyncConnectorStatistics -ConnectorName 'nationalcinemedia.onmicrosoft.com - AAD' | ft -AutoSize
}

#Wait for ADFS sync
for($i = 0 ; $i -le 0; $i=$i){
    $ErrorActionPreference = "SilentlyContinue"
    if((Get-MsolUser -UserPrincipalName $NewUserObject.userPrincipalName) -eq $null){
        Write-Host "Waiting on creation of MSOL user" -NoNewline
        Start-Sleep -s 1
        Write-Host "." -NoNewline
        Start-Sleep -s 1
        Write-Host "." -NoNewline
        Start-Sleep -s 1
        Write-Host "."
        }
    else{$i++}
}

$ErrorActionPreference = "Confirm"
#license user in O365
Set-MsolUser -UserPrincipalName $NewUserObject.userPrincipalName -UsageLocation "US"
Set-MsolUserLicense -UserPrincipalName $NewUserObject.userPrincipalname -AddLicenses nationalcinemedia:ENTERPRISEPACK
Set-MsolUserLicense -UserPrincipalName $NewUserObject.userPrincipalname -AddLicenses nationalcinemedia:EMS
 
#wait for mailbox creation
for($i = 0 ; $i -le 0; $i=$i){
    $ErrorActionPreference = "SilentlyContinue"
    if((Get-Mailbox $NewUserObject.userPrincipalName) -eq $null){
        Write-Host "Waiting on creation of mailbox" -NoNewline
        Start-Sleep -s 1
        Write-Host "." -NoNewline
        Start-Sleep -s 1
        Write-Host "." -NoNewline
        Start-Sleep -s 1
        Write-Host "."
    }
    else{$i++}
}

#generate and add smtp aliases and target address
$ErrorActionPreference = "Confirm"
[string]$mailPrimitive = ("$FirstName`.$LastName").replace("'","")
Set-ADUser $SamAccountName -Add @{proxyAddresses="SMTP:$mailPrimitive@myco.com"}
Set-ADUser $SamAccountName -Add @{proxyAddresses="smtp:$SamAccountName@myco.com"}
Set-ADUser $SamAccountName -Add @{proxyAddresses="smtp:$SamAccountName@myco.onmicrosoft.com"}
Set-ADUser $SamAccountName -Add @{proxyAddresses="smtp:$SamAccountName@myco.mail.onmicrosoft.com"}
Set-ADUser $SamAccountName -Replace @{targetAddress="SMTP:$SamAccountName@myco.mail.onmicrosoft.com"}

#set attributes that can't be set in New-ADUser
Set-ADUser $SamAccountName -Replace @{physicalDeliveryOfficeName=$NewUserObject.PhysicalDeliveryOfficeName}

#Add security group memberships
$ErrorActionPreference = "SilentlyContinue"
Get-ADPrincipalGroupMembership -identity $UsertoCopy | foreach-object {Add-ADGroupMember -Identity  $_ -Members $SamAccountName}
Add-ADGroupMember "PST Control" $SamAccountName
$ErrorActionPreference = "Prompt"

#temp user handling
if( $TempYN ){
    Remove-ADGroupMember "All Employees" $SamAccountName -ErrorAction SilentlyContinue -confirm $false
    Add-ADGroupMember "myco Contractor" $SamAccountName
    Set-ADAccountExpiration $SamAccountName -DateTime $EndDate
}
Else{
    Add-DistributionGroupMember allemployees -Member $SamAccountName
}

#enable online archive
Enable-Mailbox $NewUserObject.userPrincipalName -Archive

#disable remote powershell
Set-User $NewUserObject.userPrincipalName -RemotePowerShellEnabled $false

#enable litigation hold
Set-Mailbox $NewUserObject.userPrincipalName -LitigationHoldEnabled $true

#search for cloud-based DLs and add for user
Write-Host "Adding cloud-based DL memberships"
foreach( $group in find-CloudBasedGroupMembership $UserToCopy ){
    $Group.Name
    $group | Add-DistributionGroupMember -Member $NewUserObject.userPrincipalName -ErrorAction SilentlyContinue
}

$PayrollNotificationEmail = 'payroll@myco.com'
$mailbody = "A new user account has been created. Please add the follwing information to payroll database:
Preferred Name: $($NewUserObject.Name)
Email: $($NewUserObject.mail)
SamAccountName: $($NewUserObject.SamAccountName)"
Send-MailMessage -SmtpServer mailserver.myco.com -To $PayrollNotificationEmail -Subject 'New user notification' -Body $mailbody -from NewUserCreator@myco.com
