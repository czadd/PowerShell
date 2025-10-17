#Connect-MgGraph -Scopes 'User.Read.All'
#Get-MgUser -UserId crsmith@csmcorp.net | select -ExpandProperty AdditionalProperties
#Connect-MgGraph -Scopes "UserAuthenticationMethod.Read.All"

$Users = Get-MgUser -UserId crsmith@csmcorp.net
foreach ($user in $users) {
$authMethods = Get-MgUserAuthenticationMethod -UserId $user.Id
Write-Host "User: $($user.UserPrincipalName)"
foreach ($method in $authMethods) {
Write-Output "MFA Method: $($method.AdditionalProperties['@odata.type'])"
}
}


$user | Select *, $authMethods

Get-MgUserAuthenticationMethod