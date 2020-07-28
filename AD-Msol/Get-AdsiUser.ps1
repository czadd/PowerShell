# Get AD user using ADSI for users who don't have the RSAT tools installed
# Should work for any domain user.  I've tested on Win 7 (PS 2.0) and Win 10 (PS 5.0)

[CmdletBinding()]
PARAM(
[Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true,Position=0)][String[]]$SamAccountName
)

If( $SamAccountName ){ $Search = [adsisearcher]"(&(objectCategory=person)(objectClass=User)(Samaccountname=$SamAccountName))" }
Else{ $Search = [adsisearcher]"(&(objectCategory=person)(objectClass=User))" }
$Search.Searchroot = 'LDAP://OU=NCM Users,DC=Corporate,DC=NCM'
$Userlist = $Search.Findall()

$AdUser = foreach ($user in $UserList ){
    If( ($User.Properties.distinguishedname[0] -match 'Accounts')  ) {
        Write-Verbose "Skipping Service account. $($User.Properties.samaccountname[0])"
    }
    Else{
        Try{
            New-Object -TypeName PSObject -Property @{ 
                "DisplayName" = $user.properties.displayname[0] 
                "SamAccountName"    = $user.properties.samaccountname[0] 
                "Fname" = $user.properties.givenname[0]
                "Lname" = $user.properties.sn[0]
                "UPN" = $User.properties.userprincipalname[0]
                "Title" = $User.Properties.title[0]
                "LockoutTime" = $User.Properties.lockouttime[0]
            }
        }
        Catch{ Write-Warning "$($User.Properties.samaccountname[0]) cannot be added. Data missing" }
    }
}

$aduser
