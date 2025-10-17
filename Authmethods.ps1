<#############################################################################################
testx
 365 MFA Report
 Author: Curtis Cannon (Traversecloud.co.uk)
 https://traversecloud.co.uk/generate-authentication-methods-report-with-a-ms-graph-powershell-script
 Date: 23/03/2024

 Description:
 This script is used to generate a report of all 365 users (not guests) MFA configuration 
 it pulls information on all setup authentication methods for each user account and
 the additional details where they are available

 While this script is normally fairly fast, the more users you have in your tenant,
 the longer it will take to complete

 Additional Info:
 - Requires you to have the MS Graph Beta Powershell module installed (This will warn
   and not run if this is not present)
 - Requires you to have write access to your Root Drive (C:\)
 - This will the "C:\Temp" folder if it does not exist already
 - Report is saved to "C:\Temp" called "MFAReport.CSV" by default, this can be changed
   on ln31
 - You will be prompted to sign into an account when connecting to MS Graph
 - If you do not have "User.Read.All" & "UserAuthenticationMethod.Read.All" permissions
   already you will be prompted to accept them, if your account is not an admin you will
   have to request these permissions instead

#############################################################################################>

#Set report save location
$Logpath = "C:\Temp\MFAReport.CSV"

#Create the results array
$Results = @()

#Check for default save location and create if missing
If ((test-path "C:\Temp") -eq $false){
    New-Item -Path "C:\" -Name "Temp" -ItemType "Directory"
}

#Check for required PowerShell Module
$GraphmoduleCheck = Get-Module Microsoft.Graph -ListAvailable
If ($GraphModuleCheck -eq $null){
    Write-host -f Red "MS Graph Beta Powershell Module Not Installed!"
    Exit
}

#Connect to MG Graph with requiremed permissions
Write-host -f Cyan "Connecting to MS Graph..."
Connect-MgGraph -Scopes "User.Read.All","UserAuthenticationMethod.Read.All" -NoWelcome

#Create Arrary containing all users
$Allusers = Get-MgUser -All -Filter "Usertype eq 'Member'" | Sort Displayname
#$Allusers = Get-MgUser -UserId crsmith@csmcorp.net | Sort Displayname

#Process each user
Foreach ($User in $Allusers){
    #Reset Method Variables to default
    $AllAuthenticationMethods = ""
    $PasswordLastChanged = "-"
    $AuthenticatorName = "-"
    $PhoneDetails = "-"
    $KeyModel = "-"
    $HelloName = "-"
    $EmailAddress = "-"
    $TAPIsUsable = "-"
    $TAPStartDate = "-"
    $TAPLifetime = "-"
    $TAPUsableOnce = "-"
    $PSlessName = "-"
    $3rdpartyapp = "-"
    Write-Host -f Cyan "Processing $($user.DisplayName)"
    $AllMethods = Get-MgUserAuthenticationMethod -UserId $User.Id #Get all MFA methods for the current user
    Foreach ($Method in $AllMethods){ #Gather information on each method for the current user
        If ($Method.additionalproperties["@odata.type"] -eq "#microsoft.graph.passwordAuthenticationMethod"){
            $AuthenticationMethod = "Password"
            $PasswordCreated = (($Method.AdditionalProperties["createdDateTime"]).Split("T"))[0]
        } Elseif ($Method.additionalproperties["@odata.type"] -eq "#microsoft.graph.microsoftAuthenticatorAuthenticationMethod") {
            $AuthenticationMethod = "Authenticator App"
            $AuthenticatorName = $Method.AdditionalProperties["displayName"]
        } Elseif ($Method.additionalproperties["@odata.type"] -eq "#microsoft.graph.phoneAuthenticationMethod") {
            $AuthenticationMethod = "Phone"
            if ($PhoneDetails -eq "-"){
                $PhoneDetails = $Method.AdditionalProperties["phoneType"] + " : " + $Method.AdditionalProperties["phoneNumber"]
            } Else {
                $PhoneDetails = $PhoneDetails + ", " +  $Method.AdditionalProperties["phoneType"] + " : " + $Method.AdditionalProperties["phoneNumber"]
            }
        } Elseif ($Method.additionalproperties["@odata.type"] -eq "#microsoft.graph.fido2AuthenticationMethod"){
            $AuthenticationMethod = "FIDO2 Key"
            $KeyModel = $Method.additionalproperties["model"]
        } Elseif ($Method.additionalproperties["@odata.type"] -eq "#microsoft.graph.windowsHelloForBusinessAuthenticationMethod") {
            $AuthenticationMethod = "Windows Hello"
            $HelloName = $Method.additionalproperties["displayName"]
        } Elseif ($Method.additionalproperties["@odata.type"] -eq "#microsoft.graph.emailAuthenticationMethod") {
            $AuthenticationMethod = "Email"
            $EmailAddress = $Method.additionalproperties["emailAddress"]
        } Elseif ($Method.additionalproperties["@odata.type"] -eq "#microsoft.graph.temporaryAccessPassAuthenticationMethod") {
            $AuthenticationMethod = "Temporary Access Pass"
            $TAPIsUsable = $Method.additionalproperties["isUsable"]
            $TAPStartDate = (($Method.AdditionalProperties["startDateTime"]).Split("T"))[0]
            $TAPLifetime = [String]$Method.additionalproperties["lifetimeInMinutes"] + " Mins"
            $TAPUsableOnce = $Method.additionalproperties["isUsableOnce"]
        } Elseif ($Method.additionalproperties["@odata.type"] -eq "#microsoft.graph.passwordlessMicrosoftAuthenticatorAuthenticationMethod") {
            $AuthenticationMethod = "Passwordless Authenticator"
            $PSlessName = $Method.additionalproperties["displayName"]
        } Elseif ($Method.additionalproperties["@odata.type"] -eq "#microsoft.graph.softwareOathAuthenticationMethod") {
            $AuthenticationMethod = "3rd Party App"
            $3rdpartyapp = "Enabled"
        }
        $AllAuthenticationMethods = $AllAuthenticationMethods + $AuthenticationMethod + ","
    }
    If ($user.AssignedLicenses.Count -ge 1){
        $UserisLicensed = "True"
    }Else {
        $UserisLicensed = "False"
    }
    If ($AllMethods.Count -gt 1){
        $UserMFACapable = "True"
    }Else {
        $UserMFACapable = "False"
    }
    #Add the results for the selected user to the results array
    $Results += New-Object psobject -Property @{
        Username = $User.DisplayName
        UPN = $User.UserPrincipalName
        "Account Enabled" = $User.AccountEnabled
        "User is licensed" = $UserisLicensed
        "Capable of MFA" = $UserMFACapable
        "Authentication methods" = $AllAuthenticationMethods
        "Password Created" = $PasswordCreated
        "Authenticator App" = $AuthenticatorName
        "Phone Details" = $PhoneDetails
        "FIDO Key" = $KeyModel
        "Windows Hello" = $HelloName
        "Email Address" = $EmailAddress
        "TAP is Usable" = $TAPIsUsable
        "TAP Start Date" = $TAPStartDate
        "TAP Life Time" = $TAPLifetime
        "TAP One Time" = $TAPUsableOnce
        Passwordless = $PSlessName
        "Software OAuth" = $3rdpartyapp
    }
}

#Export Results
$Results | select Username, UPN, "Account Enabled", "User is licensed", "Capable of MFA", "Authentication methods", "Password Created", "Authenticator App", "Phone Details", "FIDO Key", "Windows Hello", "Email Address", "TAP Is Usable", "TAP Start Date", "TAP Life Time", "TAP One Time", Passwordless, "Software OAuth" | Sort Username | Format-Table -AutoSize
$Results | select Username, UPN, "Account Enabled", "User is licensed", "Capable of MFA", "Authentication methods", "Password Created", "Authenticator App", "Phone Details", "FIDO Key", "Windows Hello", "Email Address", "TAP Is Usable", "TAP Start Date", "TAP Life Time", "TAP One Time", Passwordless, "Software OAuth" | Sort Username | Export-Csv -NoTypeInformation -Path $Logpath
Write-host -f Yellow "365 MFA report is located " + $Logpath

#Disconnect from MSGraph
Disconnect-MgGraph
