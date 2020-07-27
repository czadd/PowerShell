 <#
 .Synopsis
    Collect new user information. 
 .DESCRIPTION
    Collect new user information. The resulting data will be output as an object which can be ingested by the Add-NewUser script.
 .EXAMPLE
    PS:> $UserInfo = Get-NewUserInfo.ps1
    Script will prompt for new user information and save to the $UserInfo variable
 .EXAMPLE
    PS:> Get-NewUserInfo.ps1 | Add-NewUser.ps1 
    Script will prompt for new user information and pipe it into the Add-NewUser.ps1 script.
 #>
#Requires -modules ActiveDirectory 

[CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact="High")]
Param(
    #User to copy basic info from (department, manager, address, etc.). Enter "None" to enter all information manually.
    [Parameter(Mandatory=$True, ValueFromPipelineByPropertyName=$true)][String][ValidateScript({$_ -eq 'none' -or (get-aduser $_)})]$UserToCopy,
    #New user's first name
    [Parameter(Mandatory=$False, ValueFromPipelineByPropertyName=$true)][String]$First,
    #New user's last name
    [Parameter(Mandatory=$False, ValueFromPipelineByPropertyName=$true)][String]$Last,
    #New user's middle name or initial
    [Parameter(Mandatory=$False,ValueFromPipelineByPropertyName=$true)][String]$Middle,
    #New user's name if different than the default: FirstName LastName
    [Parameter(Mandatory=$False,ValueFromPipelineByPropertyName=$true)][String]$Name,
    #New user's display name if different from name. E.g. name is Robert Smith, but he goes by Bob Smith
    [Parameter(Mandatory=$False,ValueFromPipelineByPropertyName=$true)][String]$DisplayName,
    #New user's title
    [Parameter(Mandatory=$False, ValueFromPipelineByPropertyName=$true)][String]$Title,
    #New user's description. Usually left blank.
    [Parameter(Mandatory=$False,ValueFromPipelineByPropertyName=$true)][String]$Description,
    #New user's SamAccountName if different from the default of first initial, last name
    [Parameter(Mandatory=$False,ValueFromPipelineByPropertyName=$true)][String]$SamAccountName,
    #UserPrincipalName if different from the default of samaccountname@myco.com
    [Parameter(Mandatory=$False,ValueFromPipelineByPropertyName=$true)][String][ValidateScript({$_ -match "[A-Za-z]+@myco\.com$"})]$UserPrincipalName,
    #Email address if different from the default of first.last@myco.com
    [Parameter(Mandatory=$False,ValueFromPipelineByPropertyName=$true)][String][ValidateScript({$_ -match "[A-Za-z]+\.[A-Za-z]+@myco\.com$"})]$EmailAddress,
    #Copyaddress will copy the street address, PO box, City, State, and zip from the "UserToCopy" user
    [Parameter(Mandatory=$False,ValueFromPipelineByPropertyName=$true)][Switch]$CopyAddress,
    #Street address first line
    [Parameter(Mandatory=$False,ValueFromPipelineByPropertyName=$true)][String]$StreetAddress1,
    #Street address second line
    [Parameter(Mandatory=$False,ValueFromPipelineByPropertyName=$true)][String]$StreetAddress2,
    #Street address third (last) line
    [Parameter(Mandatory=$False,ValueFromPipelineByPropertyName=$true)][String]$StreetAddress3,
    #City
    [Parameter(Mandatory=$False,ValueFromPipelineByPropertyName=$true)][String]$City,
    #State (2 letter abbreviation)
    [Parameter(Mandatory=$False,ValueFromPipelineByPropertyName=$true)][String][ValidateScript({$_ -match "^[A-Za-z]{2}$"})]$State,
    #Postal code.  00000 or 00000-0000
    [Parameter(Mandatory=$False,ValueFromPipelineByPropertyName=$true)][String][ValidateScript({$_ -match "^\d{5}(?:[-\s]\d{4})?$"})]$Zip,
    #Department if different from the UserToCopy user's department
    [Parameter(Mandatory=$False,ValueFromPipelineByPropertyName=$true)][String]$Department,
    #Manager SamAccountName if different from the UserToCopy user's department
    [Parameter(Mandatory=$False, ValueFromPipelineByPropertyName=$true)][String][ValidateScript({get-aduser $_})]$Manager,
    #Intercall (phone) number.  10 digits, no punctuation
    [Parameter(Mandatory=$False,ValueFromPipelineByPropertyName=$true)][String][ValidateScript({$_ -match "^\d{10}$"})]$Intercall,
    #Home drive if different from default of H:
    [Parameter(Mandatory=$False,ValueFromPipelineByPropertyName=$true)][String]$HomeDrive,
    #Home directory if different from default
    [Parameter(Mandatory=$False,ValueFromPipelineByPropertyName=$true)][String]$HomeDirectory,
    #Use the FinanceUser switch to automatically set the new user's home directory to the finance path
    [Parameter(Mandatory=$False,ValueFromPipelineByPropertyName=$true)][Switch]$FinanceUser,
    #Use the TempEmployee switch to set as temp. An end date will be required and the user will be removed from the myco All Employees group
    [Parameter(Mandatory=$False,ValueFromPipelineByPropertyName=$true)][Switch]$TempEmployee,
    #EndDate is required for temporary or contract employees
    [Parameter(Mandatory=$False,ValueFromPipelineByPropertyName=$true)][DateTime]$EndDate,
    #Domain. Example myco.com
    [Parameter(Mandatory=$False,ValueFromPipelineByPropertyName=$true)][String]$DomainName='myco.com'
)

#region Functions

function Get-ADParent ([string] $dn) {
     $parts = $dn -split '(?<![\\]),'
     $parts[1..$($parts.Count-1)] -join ','
}

Function Check-Aduser ($UserName) {
    Try{ If( Get-Aduser $UserName -ErrorAction SilentlyContinue) {$true} }
    Catch{ $false }
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

#region Gather user's info 

If( $UserToCopy -eq 'none' ){ 
    If( -not $pscmdlet.ShouldContinue("No user to copy was entered.`n`nContinue with manual entry?","No user to copy") ){ exit }
}
Else{
    $Copied = get-aduser $UserToCopy -Properties *
}

$FirstName = Read-Host "New user's first name" | Foreach{ (Get-culture).TextInfo.ToTitleCase($_) } 
$MiddleInitialName = Read-Host "New user's middle initial or middle name (press enter for none)" | Foreach{ (Get-culture).TextInfo.ToTitleCase($_) } 
$LastName = Read-Host "New user's last name" | Foreach{ (Get-culture).TextInfo.ToTitleCase($_) } 

if( $MiddleinitialName ){
    $Name = "$($FirstName) $($MiddleinitialName.Substring(0,1)). $($LastName)"
    $Mail = ("$($FirstName)$($MiddleinitialName.Substring(0,1)).$($Lastname)@$($DomainName)").ToLower()
    $SamAccountName = ("$($Firstname.Substring(0,1))$($MiddleInitialName.Substring(0,1))$($LastName)").ToLower()
}
else{         
    $Name = "$FirstName $LastName"
    $SamAccountName = ("$($Firstname.Substring(0,1))$($LastName)").ToLower()
    $Mail = ("$($FirstName).$($Lastname)@$($DomainName)").tolower()
}

$CustomSam = Read-Host "SamAccountName (Enter for `"$SamaccountName`")"
If( $CustomSam ){ $SamAccountName = $CustomSam.ToLower() }

$NewName = Read-Host "Name (Enter for `"$($Name)`")"
If( $newName ){ $Name = $NewName }
$Name = $Name | Foreach{ (Get-culture).TextInfo.ToTitleCase($_) } 

$DisplayName = Read-Host "DisplayName (Enter for `"$($Name)`")"
If( -not $Displayname ){ $DisplayName = $Name }
$Displayname = $DisplayName | Foreach{ (Get-culture).TextInfo.ToTitleCase($_) } 

[Regex]$MailFormat = "[A-Za-z]+\.[A-Za-z]+@myco\.com$"
Do{ $CustomMail = Read-Host "Email address (Enter for $mail)" } Until( ($CustomMail -match $MailFormat) -or (-not $CustomMail) )
If( $CustomMail ){ $Mail = $CustomMail }

If( Check-Aduser $SamAccountName ){
    Write-Warning "SamAccountName $SamAccountName already exists. Please choose a new SamAccountName."
    Do{ $SamAccountName = Read-Host "New user's sAMAccount Name (e.g. 'jdoe')"}
    Until( $SamAccountName.Length -gt 0 -and (-not (Check-Aduser $SamAccountName)) )
}
$UPN = ("$($SamAccountName)@$($DomainName)").ToLower()

#request address
If( $Copied.StreetAddress ){
    #Write-Host "Address copied from $($UsertoCopy):`n$($Copied.StreetAddress)`n$($Copied.City), $($Copied.St) $($Copied.PostalCode)"
    Do{ $CopyAddressYN = Read-Host "Use copied address?`n$($Copied.StreetAddress)`n$($Copied.City), $($Copied.St) $($Copied.PostalCode)`n(y/n)" } Until( $CopyAddressYN -match '[yn]' )
    If( $CopyAddressYn -match 'y' ){ 
        $StreetAddress = $Copied.StreetAddress 
        $City = $Copied.City
        $State = $Copied.St
        $Zip = $Copied.PostalCode
        $Country = $Copied.Co
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
            $Country = Read-Host "Country (enter for United States)" 
            If( -not $Country ){ $Country = 'United States' }
        }
        if($NewUserStreet2.length -eq 0){$StreetAddress = $NewUserStreet1}
        else{
            if($NewUserStreet3.length -eq 0){$StreetAddress = ($NewUserStreet1 + "`r`n" + $NewUserStreet2)}
            else{$StreetAddress = ($NewUserStreet1 + "`r`n" + $NewUserStreet2 + "`r`n" + $NewUserStreet3)}
        }
    }
}

#request additional information
$Title = Read-Host "New user's title" 
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
If( $FinanceYn -match 'n' ){ $HomeDirectory = ("\\$($DomainName)\user\home$\" + $SamAccountName);$HomeDirectoryLocation = "\\corporate.myco\user\home$\"}
Else{$HomeDirectory = ("\\$($DomainName)\user\finhome$\" + $SamAccountName);$HomeDirectoryLocation = "\\$($DomainName)\user\finhome$"}

[regex]$digits="^\d{10}$"
Do{ $IntercallTemp = Read-Host "Intercall Reservationless Plus number from TCC online (10 digits, no punctuation). Enter to skip" }
Until( ($IntercallTemp -match $digits ) -or $IntercallTemp -eq '' )
If( $IntercallTemp ){ $Intercall = $IntercallTemp }

#endregion Gather user's info 

#region Validate user info and populate params
#TODO: CHECK for exisiting samaccountname, upn, email
#endregion Validate user info and populate params

#region Generate user objects and display for verification

If( $Copied ){ 
    $NewUserObject = New-Object PsObject -Property @{ 'CopiedUser' = $Copied }
    $Department = $Copied.department
    $Company = $Copied.company
    $Manager = get-aduser $Copied.manager | select -ExpandProperty SamAccountName
    $OU = get-adparent $Copied
    $PhysicalDeliveryOfficeName = $Copied.physicalDeliveryOfficeName
    $Country = $Copied.Country
    $Co = $Copied.Co
}
Else{
    $NewUserObject = New-Object PsObject -Property @{ 'CopiedUser' = $UserToCopy }
    $Department = Read-Host 'Department (e.g. `"Sales and marketing`")'
    $CO = Read-Host "Country (Enter for United States)"
    If( -not $CO ){ $CO = 'United States' }
    $Company = Read-Host "Company (Enter for `"Myco`")"
    If( -not $Company ){ $Company = 'Myco' }
    Do{ $Manager = Read-Host "Manager (SamAccountName)" } Until( Check-Aduser $Manager )
    Do{ 
        Do{ $OUName = Read-Host "Organizational Unit (OU) name E.g: `"HR`"" } Until( $ouName.Length -gt 0 )
        $OU = Get-ADOrganizationalUnit -filter 'name -eq $OUName' -ErrorAction SilentlyContinue
    }
    Until( $OU )
    $PhysicalDeliveryOfficeName = Read-Host "Office name"
}

$NewUserObject | Add-Member -MemberType NoteProperty -Name 'SamAccountName' -Value $SamAccountName
$NewUserObject | Add-Member -MemberType NoteProperty -Name 'UserPrincipalName' -Value $UPN
$NewUserObject | Add-Member -MemberType NoteProperty -Name 'GivenName' -Value $FirstName
$NewUserObject | Add-Member -MemberType NoteProperty -Name 'SurName' -Value $LastName
$NewUserObject | Add-Member -MemberType NoteProperty -Name 'MiddleName' -Value $MiddleinitialName
$NewUserObject | Add-Member -MemberType NoteProperty -Name 'Name' -Value $Name
$NewUserObject | Add-Member -MemberType NoteProperty -Name 'DisplayName' -Value $DisplayName
$NewUserObject | Add-Member -MemberType NoteProperty -Name 'EmailAddress' -Value $Mail
$NewUserObject | Add-member -MemberType NoteProperty -Name 'Intercall' -Value $Intercall
$NewUserObject | Add-member -MemberType NoteProperty -Name 'Description' -Value $Description
$NewUserObject | Add-member -MemberType NoteProperty -Name 'StreetAddress' -Value $StreetAddress
$NewUserObject | Add-member -MemberType NoteProperty -Name 'POBox' -Value $POBox
$NewUserObject | Add-member -MemberType NoteProperty -Name 'City' -Value $City
$NewUserObject | Add-member -MemberType NoteProperty -Name 'ST' -Value $State
$NewUserObject | Add-member -MemberType NoteProperty -Name 'PostalCode' -Value $Zip
$NewUserObject | Add-member -MemberType NoteProperty -Name 'Country' -Value $Country
$NewUserObject | Add-member -MemberType NoteProperty -Name 'CO' -Value $CO
$NewUserObject | Add-member -MemberType NoteProperty -Name 'HomeDrive' -Value $HomeDrive
$NewUserObject | Add-member -MemberType NoteProperty -Name 'HomeDirectory' -Value $HomeDirectory
$NewUserObject | Add-member -MemberType NoteProperty -Name 'FinanceUser' -Value $FinanceYN.Toupper()
$NewUserObject | Add-member -MemberType NoteProperty -Name 'TempEmployee' -Value $TempYN.ToUpper()
$NewUserObject | Add-member -MemberType NoteProperty -Name 'Title' -Value $Title
$NewUserObject | Add-member -MemberType NoteProperty -Name 'AccountExpirationDate' -Value $EndDate
$NewUserObject | Add-member -MemberType NoteProperty -Name 'Department' -Value $Department
$NewUserObject | Add-member -MemberType NoteProperty -Name 'Company' -Value $Company
$NewUserObject | Add-member -MemberType NoteProperty -Name 'Manager' -Value $Manager
$NewUserObject | Add-member -MemberType NoteProperty -Name 'PhysicalDeliveryOfficeName' -Value $PhysicalDeliveryOfficeName
#$NewUserObject | Add-member -MemberType NoteProperty -Name '' -Value

$NewUserObject | Select UserToCopy,First,Last,Middle,Name,Displayname,Title,Description,SamaccountName,UserPrincipalName,EmailAddress,StreetAddress,City,State,Zip,Company,Department,Manager,Intercall,HomeDrive,HomeDirectory,FinanceUser,TempEmployee,EndDate

If( -not $pscmdlet.ShouldContinue("
CopiedUser: $($NewUserObject.CopiedUser.SamAccountName)
First Name: $($NewUserObject.GivenName)
Last Name: $($NewuserObject.SurName)
Middle Name: $($NewuserObject.MiddleName)
Name: $($NewuserObject.Name)
Displayname: $($NewuserObject.DisplayName)
SamaccountName: $($NewuserObject.SamAccountName)
UPN: $($NewuserObject.UserPrincipalName)
EmailAddress: $($NewuserObject.EmailAddress)
StreetAddress: $($NewuserObject.StreetAddress)
City: $($NewuserObject.City)
State: $($NewuserObject.St)
Zip: $($NewuserObject.PostalCode)
Country: $($NewUserObject.CO) `($($NewUserObject.Country)`)
Company: $($NewuserObject.Company)
Department: $($NewuserObject.Department)
Manager: $($NewuserObject.Manager)
Title: $($NewuserObject.Title)
Description: $($NewuserObject.Description)
Intercall: $($NewuserObject.Intercall)
HomeDrive: $($NewuserObject.HomeDrive)
HomeDirectory: $($NewuserObject.HomeDirectory)
FinanceUser: $($NewuserObject.FinanceUser)
TempEmployee: $($NewuserObject.TempEmployee)
EndDate: $($NewuserObject.AccountExpirationDate)

"
, "Is information correct?") ){ exit }

$NewUserObject

#endregion Generate user objects and display for verification