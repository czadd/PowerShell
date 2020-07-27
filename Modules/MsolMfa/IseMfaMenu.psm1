If( Test-path 'c:\repo\sa\Modules\MsolMfa' ){
    cd c:\repo\sa\Modules\MsolMfa
}
Else{
    If( Test-path '\\corp.czadd\share\scripts\Modules\MsolMfa' ){
        cd '\\corp.czadd\share\scripts\Modules\MsolMfa'
    }
}

#. .\Connect-Office365Function.ps1

If( get-command connect-office365 ){

    If( $psISE ){

        Write-Verbose 'Getting tools menu root'
        $MsRemoteMenu = $psISE.CurrentPowerShellTab.AddOnsMenu.Submenus.where({$_.DisplayName -eq "_MS Remoting"})	
        if (-not $MsRemoteMenu ) { 
            $MsRemoteMenu = $psISE.CurrentPowerShellTab.AddOnsMenu.SubMenus.Add("_MS Remoting",$null,$null) 
        }

        Write-Verbose 'Adding standard remoting'
        If( -not( $MsRemoteMenu.Submenus.Where({$_.Displayname -eq 'AzureAD'}) ) ) {
            $MsRemoteMenu.Submenus.Add('AzureAD', {Connect-Office365 -Service AzureAD} ,$Null) 
        }
        If( -not( $MsRemoteMenu.Submenus.Where({$_.Displayname -eq 'Exchange'}) ) ) {
            $MsRemoteMenu.Submenus.Add('Exchange', {Connect-Office365 -Service Exchange} ,$Null)
        }
        If( -not( $MsRemoteMenu.Submenus.Where({$_.Displayname -eq 'MSOnline'}) ) ) {
            $MsRemoteMenu.Submenus.Add('MSOnline', {Connect-Office365 -Service MSOnline} ,$Null) 
        }
        If( -not( $MsRemoteMenu.Submenus.Where({$_.Displayname -eq 'Security And Compliance'}) ) ) {
            $MsRemoteMenu.Submenus.Add('Security And Compliance', {Connect-Office365 -Service SecurityAndCompliance} ,$Null) 
        }
        If( -not( $MsRemoteMenu.Submenus.Where({$_.Displayname -eq 'SharePoint'}) ) ) {
            $MsRemoteMenu.Submenus.Add('SharePoint', {Connect-Office365 -Service SharePoint} ,$Null)
        }
        If( -not( $MsRemoteMenu.Submenus.Where({$_.Displayname -eq 'SkypeForBusiness'}) ) ) {
            $MsRemoteMenu.Submenus.Add('SkypeForBusiness', {Connect-Office365 -Service SkypeForBusiness} ,$Null) 
        }

        Write-Verbose 'Adding MFA remoting'
        If( -not( $MsRemoteMenu.Submenus.Where({$_.Displayname -eq 'MFA - AzureAD'}) ) ) {
            $MsRemoteMenu.Submenus.Add('MFA - AzureAD', {Connect-Office365 -Service AzureAD -MFA} ,'Ctrl+Alt+A') 
        }
        If( -not( $MsRemoteMenu.Submenus.Where({$_.Displayname -eq 'MFA - Exchange'}) ) ) {
            $MsRemoteMenu.Submenus.Add('MFA - Exchange', {Connect-Office365 -Service Exchange -MFA} ,'Ctrl+Alt+E') 
        }
        If( -not( $MsRemoteMenu.Submenus.Where({$_.Displayname -eq 'MFA - MSOnline'}) ) ) {
            $MsRemoteMenu.Submenus.Add('MFA - MSOnline', {Connect-Office365 -Service MSOnline -MFA} ,'Ctrl+Alt+O') 
        }
        If( -not( $MsRemoteMenu.Submenus.Where({$_.Displayname -eq 'MFA - Security And Compliance'}) ) ) {
            $MsRemoteMenu.Submenus.Add('MFA - Security And Compliance', {Connect-Office365 -Service SecurityAndCompliance -MFA} ,'Ctrl+Alt+C') 
        }
        If( -not( $MsRemoteMenu.Submenus.Where({$_.Displayname -eq 'MFA - SharePoint'}) ) ) {
            $MsRemoteMenu.Submenus.Add('MFA - SharePoint', {Connect-Office365 -Service SharePoint -MFA} ,'Ctrl+Alt+P') 
        }
        If( -not( $MsRemoteMenu.Submenus.Where({$_.Displayname -eq 'MFA - SkypeForBusiness'}) ) ) {
            $MsRemoteMenu.Submenus.Add('MFA - SkypeForBusiness', {Connect-Office365 -Service SkypeForBusiness -MFA} ,'Ctrl+Alt+S') 
        }

    }
}
Else{ Write-Warning 'Unable to load Connect-Office365 function. Before connecting to Exchange MFA, import the module like this: . .\Connect-O365mfa.ps1' }

export-modulemember -function * -variable * -alias * -Cmdlet *