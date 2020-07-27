 <#
 .Synopsis
    Terminate user. 
 .DESCRIPTION
    Set termination date, remove group memberships, save group membership details to a text file, set email forwarding, etc.
 .EXAMPLE
    PS:> O365 User Termination Script.ps1
    Script will prompt for user to terminate
 .EXAMPLE
    PS:> O365 User Termination Script.ps1 -UserToTerminate jdoe -EmailForwardAddress someone@company.com 
    Script will run with no prompts to terminate the jdoe user and forward to someone@company.com
.NOTES
   Script assumes that exchange alias is identical to AD alias and that length of mail forward is 30 days, these may have to be adjusted in rare cases
 #>
#Requires -modules ActiveDirectory 

[CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact="High")]
Param(
    # SAMAccountName of the user to terminate
    [Parameter(Mandatory=$false,ValueFromPipelineByPropertyName=$true,Position=0)][String]$UserToTerminate,
    # SAMAccountname of the user to forward email to
    [Parameter(Mandatory=$false,ValueFromPipelineByPropertyName=$true,Position=1)][String]$EmailForwardAddress,
    # Max seconds to wait for MSOL Sync
    [Parameter(Mandatory=$false,ValueFromPipelineByPropertyName=$true,Position=2)][Int]$MaxWaitSeconds = 120,
    # The UseSavedCreds switch will enable used of credentials saved to a clixm file.
    [Parameter(Mandatory=$false,ValueFromPipelineByPropertyName=$true,Position=3)][Alias('SC')][Switch]$UseSavedCreds=$False,
    # Path to saved credential. Use with UseSavedCreds switch
    [Parameter(Mandatory=$false,ValueFromPipelineByPropertyName=$true,Position=0)][String]$SavedCredPath = (Join-Path $env:APPDATA 'MsolCred.xml')
)

#function to find cloud-based DLs
function find-CloudBasedGroupMembership ([string]$UserToSearch){
    $ADGroups = get-adprincipalgroupmembership $UserToSearch
    Get-DistributionGroup -ResultSize unlimited | Where { $_.name -in $ADGroups.name }
}

If( -Not $UsertoTerminate ){ $UsertoTerminate = Read-Host "User to terminate (SAMAccountName)." }
 
If( -Not $MFA ){
    If( $UseSavedcreds ){
        If( test-path $SavedCredPath ){ $Cred = Import-Clixml $SavedCredPath }
        Else{ 
            $cred = Get-Credential "$($Env:Username)@czadd.com"
            $Cred | Export-Clixml $SavedCredPath
        }
    }
    Else{ $Cred = Get-Credential "$($Env:Username)@czadd.com" }

    #connect to MsOnline
    Connect-Office365 -Service MSOnline -Credential $Cred
    Connect-Office365 -Service Exchange -Credential $Cred
}

#region O365 MFA connections
If( $MFA ){
    If( -not (get-command Connect-Office365 -ErrorAction SilentlyContinue) ){
        Throw 'Connect-Office365 function not found. Load the Connect-Office365 function before running this script.'
    }

    If( -not (get-command Get-FederatedOrganizationIdentifier -ErrorAction SilentlyContinue) ){ 
        Write-Host 'Initiating Exchange (MFA) connection.'
        Connect-Office365 -Service Exchange -MFA
        If( -not (get-command Get-FederatedOrganizationIdentifier -ErrorAction SilentlyContinue) ){ Throw 'Unable to connect to Exchange using MFA.' }
        Else{ Write-Host 'Exchange (MFA) connected.' }
    }
    Else{ Write-Verbose 'Existing connection found to Exchange MFA' }

    If( -not (Get-MsolAccountSku -ErrorAction SilentlyContinue) ){
        Write-Host 'Initiating MSOnline (MFA) connection.'
        Connect-Office365 -Service MSOnline -MFA 
        If( -not (Get-MsolAccountSku -ErrorAction SilentlyContinue) ){ Throw 'Unable to connect to MSOnline using MFA.' }
        Else{ Write-Host 'MSOnline (MFA) connected.' }
    }
    Else{ Write-Verbose 'Existing connection found to MSOnline MFA' }
}
#endregion O365 MFA connections

#list all group memberships from $UsertoTerminate prior to removal and write to G drive
Write-Host "AD Groups:"
Get-ADPrincipalGroupMembership -identity $UsertoTerminate | foreach-object {write-host $_.name }
Get-ADPrincipalGroupMembership -identity $UsertoTerminate | select-object name | Out-File -FilePath "\\corp.czadd\share\User Chantes\Term\$UsertoTerminate.txt" -Append
Write-Host 
Write-Host "Disabling user and removing group memberships."

#add 'domain guests' group
Add-ADGroupMember "Domain Guests" $UsertoTerminate 

#set 'domain guests' as pimary group
Get-ADUser $UsertoTerminate | Set-ADObject -Replace @{primaryGroupID=514}

#clear all group memberships from $UsertoTerminate (except primary group)
Get-ADPrincipalGroupMembership $UsertoTerminate | Where name -ne 'Domain Guests' | foreach-object {Remove-ADGroupMember -Identity $_ -member $UsertoTerminate -Confirm:$false}

#Enddate account today
Write-Host "Setting end date"
$today = [DateTime]::Today
Set-ADUser -identity $UsertoTerminate -AccountExpirationDate $today

#Grant Desktop Support permissions to home folder
$UserFolder = get-aduser $UserToTerminate -Properties Homedirectory | Select -ExpandProperty Homedirectory

Do{ $YN = Read-Host "Would you like the script to set home directory permissions? (Y/N)" } Until( $YN -match '[yn]' ) #Added this because the script can hang while setting ACLs.
If( $YN -match 'y' ){
    $Server = $Env:Computername 
    If( $Env:Computername -eq $Server ){
        Write-Host "Setting home directory permissions (locally). This may take several minutes." 
        $DesktopACL = get-acl '\\corp.czadd\shares\user changes\ReferenceDir'
        set-acl -path $UserFolder -AclObject $DesktopACL -Passthru
    }
    Else{
        Write-Host "Setting home directory permissions (remotely on to $Server). This may take several minutes." 
        If( -not (Test-connection $server -Count 2 -Quiet) ){
            Write-Warning "$Server could not be contacted. Folder permissions must be set manually."
        }
        Invoke-Command -ComputerName $Server -ScriptBlock {
            $DesktopACL = get-acl '\\corp.czadd\shares\user changes\ReferenceDir'
            set-acl -path $USING:UserFolder -AclObject $DesktopACL 
            Get-acl -path $USING:UserFolder | Select -ExpandProperty Access | select IdentityReference,FileSystemRights
        }
    }
}
Else{ Write-Warning "Please manually set permissions on folder: $($UserFolder)" }

#add description to user account with deletion date
Write-Host "Setting end date and description" 
$deletiondate = [DateTime]::Today.AddDays(30)
$deletiondate = "$deletiondate"
$deletiondate = $deletiondate.replace("00:00:00","")
set-aduser $UsertoTerminate -description "delete on $deletiondate"

#hide user from Address List
Write-Host "Hiding from GAL"
Set-adUser $UsertoTerminate -Replace @{msExchHideFromAddressLists=$True} 
#get-aduser $UsertoTerminate -Properties msExchHideFromAddressLists | select msExchHideFromAddressLists

#randomize password
Write-Host "Setting random password"
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
Set-ADAccountPassword -Identity $UsertoTerminate -NewPassword $SecurePassword

#Connect to czaddDIRSYNC and sync user to MSOL
$ADFSSession = New-PSSession -ComputerName AADSyncSvr -Credential $Cred -Authentication Kerberos
Invoke-Command -Session $ADFSSession -ScriptBlock {
    $SyncStatus = Get-ADSyncConnectorRunStatus
    If( $SyncStatus ){ Write-Host "AD Sync is already in progress." -NoNewline -ForegroundColor Yellow }
    Else{ 
        Write-host "Syncing w/ MSOL." -NoNewline
        Start-ADSyncSyncCycle -PolicyType Delta
    }
    
    Do{
        Start-sleep -Seconds 3
        $SyncStatus = Get-ADSyncConnectorRunStatus
        Write-Host "."  -NoNewline
    }
    While ( $SyncStatus )
    Get-ADSyncConnectorStatistics -ConnectorName 'czadd.onmicrosoft.com - AAD' | ft -AutoSize
}
$ADFSSession | Remove-PSSession

Write-Host "Waiting on MSOL sync."
For( $i=1 ; ($i -lt $MaxWaitSeconds) -and ($Mailbox.hiddenfromaddresslistsenabled -ne $True) ; $i ++ ){
    Write-Progress -Id 0 -Activity "Waiting on MSOL sync" -Status "$i / $MaxWaitSeconds seconds" -PercentComplete ($i / $MaxWaitSeconds * 100)
    $Mailbox = get-mailbox $UsertoTerminate # | select -ExpandProperty hiddenfromaddresslistsenabled) -eq $False
    If( $Mailbox.hiddenfromaddresslistsenabled -eq $True ){ $Status = 'Hidden' }
    Else{ Start-sleep -Seconds 1 }
}
If( -not ($Mailbox.HiddenFromAddressListsEnabled -eq $True) ){
    Write-Progress -id 0 -Completed -Activity "Waiting on MSOL sync"
    If( -not $pscmdlet.ShouldContinue("MSOL sync failed.  Please manually sync. `n`nContinue anyway?`n","MSOL sync failed") ){ exit }
}
Else{
    Write-Progress -id 0 -Completed -Activity "Waiting on MSOL sync"
    Write-Host 
}

#Different handling depending on whether email forward is requested or not
Write-Host "Setting email forward and disabling account"
If( -Not $EmailForwardAddress ){ $EmailForwardAddress = Read-host "username to forward email. Leave blank for none" }
If ( (-Not $EmailForwardAddress) -Or ($EmailForwardAddress -eq "none") -or ($EmailForwardAddress -eq '') ){
    #disable account
    Disable-ADAccount -identity $UsertoTerminate 
    #move $UsertoTerminate 'disabled accounts' OU
    Move-ADObject (Get-ADUser -identity $UsertoTerminate) -targetpath "OU=Disabled Accounts,DC=corp,DC=czadd"
}
else{
    #forward email to $EmailForward
    $EmailForwardAddress = Get-ADUser -identity $EmailForwardAddress -properties emailaddress | select-object -ExpandProperty emailaddress
    Set-Mailbox -Identity $UsertoTerminate -ForwardingAddress $EmailForwardAddress
    #disable account
    Disable-ADAccount -identity $UsertoTerminate 
    #move $UsertoTerminate to 'email forward' OU
    Move-ADObject (Get-ADUser -identity $UsertoTerminate) -targetpath "OU=email Forward,OU=Disabled Accounts,DC=corp,DC=czadd"
}

#remove cloud-based DL memberships
write-host "Removing user from cloud-based DLs."
$cloudgroups = Find-CloudBasedGroupMembership($UsertoTerminate)
foreach($group in $cloudgroups){
    Remove-DistributionGroupMember $group -Member $UsertoTerminate
}
  
#disconnect from Exchange
#Remove-PSSession $O365Session

#Connect-MsolService -Credential $cred

$UsertoTerminateUPN = get-aduser $UsertoTerminate | select -ExpandProperty userprincipalname

If( ($EmailForwardAddress -eq "none") -or ($EmailForwardAddress -eq '') ){ Remove-Variable EmailForwardAddress }
If( $EmailForwardAddress ){
    Write-Host "Retaining MSOL Enterprisepack and EMS licenses in order to enable mail forwarding."
    $MsolLicense = get-msoluser -UserPrincipalName $UsertoTerminateUPN | Select -ExpandProperty Licenses | Where{ ($_.AccountSkuId -notmatch 'ENTERPRISEPACK') -AND ($_.AccountSkuId -notmatch 'ENTERPRISEPREMIUM') -and ($_.AccountSkuId -notmatch 'EMS') }    
}
Else{
    Write-Host "Removing all MSOL user licenses."
    $MsolLicense = get-msoluser -UserPrincipalName $UsertoTerminateUPN | Select -ExpandProperty Licenses
}

#unlicense user
Foreach( $License in $MsolLicense ){
    Set-MsolUserlicense -UserPrincipalName $UsertoTerminateUPN -RemoveLicenses $License.AccountSkuId -ErrorAction SilentlyContinue
}
$MsolLicense = get-msoluser -UserPrincipalName $UsertoTerminateUPN | Select -ExpandProperty Licenses

Write-Host "Done.  Displaying results."
Get-Aduser $UserToTerminate -Properties * | Select Name,SamAccountName,DistinguishedName,Description,AccountExpirationDate,Enabled,@{l='MemberOf';e={(Get-ADPrincipalGroupMembership $UserToTerminate).name}},msExchHideFromAddressLists,@{l='MsolLicenses';e={$MsolLicense.AccountSku.SkuPartNumber -join ','}}
