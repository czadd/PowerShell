If( $psISE ){

    #region Tools menu root
    $toolsMenu = $psISE.CurrentPowerShellTab.AddOnsMenu.Submenus.where({$_.DisplayName -eq "_Tools"})	
    if (-not $toolsMenu ) { 
        $toolsMenu = $psISE.CurrentPowerShellTab.AddOnsMenu.SubMenus.Add("_Tools",$null,$null) 
    }
    #endregion

    #region ISE Comments from PoshCode
    #requires -version 2.0
    ## ISE-Comments module v 1.1
    ##############################################################################################################
    ## Provides Comment cmdlets for working with ISE
    ## ConvertTo-BlockComment - Comments out selected text with <# before and #> after
    ## ConvertTo-BlockUncomment - Removes <# before and #> after selected text
    ## ConvertTo-Comment - Comments out selected text with a leeding # on every line 
    ## ConvertTo-Uncomment - Removes leeding # on every line of selected text
    ##
    ## Usage within ISE or Microsoft.PowershellISE_profile.ps1:
    ## Import-Module ISE-Comments.psm1
    ##
    ## Note: The IsePack, a part of the PowerShellPack, also contains a "Toggle Comments" command,
    ##       but it does not support Block Comments
    ##       http://code.msdn.microsoft.com/PowerShellPack
    ##
    ##############################################################################################################
    ## History:
    ## 1.1 - Minor alterations to work with PowerShell 2.0 RTM and Documentation updates (Hardwick)
    ## 1.0 - Initial release (Poetter)
    ##############################################################################################################


    ## ConvertTo-BlockComment
    ##############################################################################################################
    ## Comments out selected text with <# before and #> after
    ## This code was originaly designed by Jeffrey Snover and was taken from the Windows PowerShell Blog.
    ## The original function was named ConvertTo-Comment but as it comments out a block I renamed it.
    ##############################################################################################################
    function ConvertTo-BlockComment
    {
        $editor = $psISE.CurrentFile.Editor
        $CommentedText = "<#`n" + $editor.SelectedText + "`n#>"
        # INSERTING overwrites the SELECTED text
        $editor.InsertText($CommentedText)
    }

    ## ConvertTo-BlockUncomment
    ##############################################################################################################
    ## Removes <# before and #> after selected text
    ##############################################################################################################
    function ConvertTo-BlockUncomment
    {
        $editor = $psISE.CurrentFile.Editor
        $CommentedText = $editor.SelectedText -replace ("^<#`n", "")
        $CommentedText = $CommentedText -replace ("#>$", "")
        # INSERTING overwrites the SELECTED text
        $editor.InsertText($CommentedText)
    }

    ## ConvertTo-Comment
    ##############################################################################################################
    ## Comments out selected text with a leeding # on every line
    ##############################################################################################################
    function ConvertTo-Comment
    {
        $editor = $psISE.CurrentFile.Editor
        $CommentedText = $editor.SelectedText.Split("`n")
        # INSERTING overwrites the SELECTED text
        $editor.InsertText( "#" + ( [String]::Join("`n#", $CommentedText)))
    }

    ## ConvertTo-Uncomment
    ##############################################################################################################
    ## Comments out selected text with <# before and #> after
    ##############################################################################################################
    function ConvertTo-Uncomment
    {
        $editor = $psISE.CurrentFile.Editor
        $CommentedText = $editor.SelectedText.Split("`n") -replace ( "^#", "" )
        # INSERTING overwrites the SELECTED text
        $editor.InsertText( [String]::Join("`n", $CommentedText))
    }

    ##############################################################################################################
    ## Inserts a submenu Comments to ISE's Custum Menu
    ## Inserts command Block Comment Selected to submenu Comments
    ## Inserts command Block Uncomment Selected to submenu Comments
    ## Inserts command Comment Selected to submenu Comments
    ## Inserts command Uncomment Selected to submenu Comments
    ##############################################################################################################

    #$toolsMenu = $psISE.CurrentPowerShellTab.AddOnsMenu.Submenus.where({$_.DisplayName -eq "_Tools"})	
    #if (-not $toolsMenu ) { $toolsMenu = $psISE.CurrentPowerShellTab.AddOnsMenu.SubMenus.Add("_Tools",$null,$null) }

        If( -not( $toolsMenu.Submenus.Where({$_.Displayname -eq '_Block Comment Selected'}) ) ) {
            $toolsMenu.Submenus.Add("_Block Comment Selected", {ConvertTo-BlockComment}, "Ctrl+SHIFT+B")
        }
        If( -not( $toolsMenu.Submenus.Where({$_.Displayname -eq '_Block Uncomment Selected'}) ) ) { 
            $toolsMenu.Submenus.Add("_Block Uncomment Selected", {ConvertTo-BlockUncomment}, "Ctrl+Alt+B") 
        }
        If( -not( $toolsMenu.Submenus.Where({$_.Displayname -eq '_Comment Selected'}) ) ) {
            $toolsMenu.Submenus.Add("_Comment Selected", {ConvertTo-Comment}, "Ctrl+SHIFT+M")
        }
        If( -not( $toolsMenu.Submenus.Where({$_.Displayname -eq '_Uncomment Selected'}) ) ) {
            $toolsMenu.Submenus.Add("_Uncomment Selected", {ConvertTo-Uncomment}, "Ctrl+Alt+M")
        }

    # If you are using IsePack (http://code.msdn.microsoft.com/PowerShellPack) and IseCream (http://psisecream.codeplex.com/),
    # you can use this code to add your menu items. The added benefits are that you can specify the order of the menu items and
    # if the shortcut already exists it will add the menu item without the shortcut instead of failing as the default does.
    # Add-IseMenu -Name "Comments" @{            
    #    "Block Comment Selected"  = {ConvertTo-BlockComment}| Add-Member NoteProperty order  1 -PassThru  | Add-Member NoteProperty ShortcutKey "Ctrl+SHIFT+B" -PassThru
    #    "Block Uncomment Selected" = {ConvertTo-BlockUncomment}| Add-Member NoteProperty order  2 -PassThru  | Add-Member NoteProperty ShortcutKey "Ctrl+Alt+B" -PassThru
    #    "Comment Selected" = {ConvertTo-Comment}| Add-Member NoteProperty order  3 -PassThru  | Add-Member NoteProperty ShortcutKey "Ctrl+SHIFT+C" -PassThru
    #    "Uncomment Selected"  = {ConvertTo-Uncomment}| Add-Member NoteProperty order  4 -PassThru  | Add-Member NoteProperty ShortcutKey "Ctrl+Alt+C" -PassThru
    #    }

    #endregion

    #region IseSnippet
    Function ConvertTo-IseSnippet{
        $editor = $psISE.CurrentFile.Editor
        $editor.SelectedText
    
        New-IseSnippet -Title (Read-Host "Title") -Description (Read-Host "Description") -Text $editor.SelectedText
    }


    If( -not( $toolsMenu.Submenus.Where({$_.Displayname -eq '_New Snippet'}) ) ) { 
        $null = $toolsMenu.Submenus.Add("_New Snippet", {ConvertTo-IseSnippet}, "Shift+Alt+S")
    }

    #endregion

    #region New-PsIseGuid
    Function New-PsIseGuid{
        $Guid = ([GUID]::NewGuid()).GUID

        $editor = $psISE.CurrentFile.Editor
        # INSERTING overwrites the SELECTED text
        $editor.InsertText( [String]::Join("`n", $Guid))
    }

    if (-not( $psISE.CurrentPowerShellTab.AddOnsMenu.Submenus.where({$_.DisplayName -eq "_Tools"}) ) ){
	    $toolsMenu = $psISE.CurrentPowerShellTab.AddOnsMenu.SubMenus.Add("_Tools",$null,$null) 
    }
    If( -not( $toolsMenu.Submenus.Where({$_.Displayname -eq '_New GUID'}) ) ){
        $toolsMenu.Submenus.Add("_New GUID", {New-PsIseGuid}, "Shift+Alt+G")
    }
    #endregion

    #region Show-VerboseMessaging
    Function Set-VerbosePreference{
        If( $Global:VerbosePreference -eq 'Continue' ){ $Global:VerbosePreference = 'SilentlyContinue' }
        ElseIf( $Global:VerbosePreference -eq 'SilentlyContinue' ){ $Global:VerbosePreference = 'Continue' }
        Else{ $Global:VerbosePreference = 'Continue' }
        Write-Host "VerbosePreference: $($Global:VerbosePreference)"
    } 
    
    If( -not( $toolsMenu.Submenus.Where({$_.Displayname -eq '_Verbose Toggle'}) ) ){ 
        $toolsMenu.Submenus.Add("_Verbose Toggle", {Set-VerbosePreference}, "CTRL+Alt+V")
    }

    #endregion

    export-modulemember -function * -variable * -alias * -Cmdlet *

}