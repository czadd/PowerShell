#region General Git stuff

#Add GIT to the path, adjust accordingly
if ($env:Path -Notlike 'C:\Program Files\Git\bin') {$env:path+=';C:\Program Files\Git\bin'}

#endregion


#region Git PS ISE ##Creates the SMA ISE Demo addon to manage SMA runbooks and hook them into GIT.

If( $PsIse ){
    #Use the $psISE.CurrentFile to interact/reference the current file,
    #Example: "$psISE.CurrentFile.FullPath"
    #Example: $psISE.CurrentFile.Save()
    #Example:  if ($psISE.CurrentFile.IsSaved) {}

    #clears all Submenus to avoid duplication, once per menu customization script.
    $psISE.CurrentPowerShellTab.AddOnsMenu.Submenus.Clear()

    #Local Repo, enter the folder to create the GIT SMA projects in
    #$LocalRepo = 'D:\repo\czadd\SMA\Runbooks' 

    #evalue if machine has pre-reqs, user has access, whatever.
    #$showSMAPublishing = $true
    #if ($showSMAPublishing){}

    #Set some variables to save us time
   # $smaWeb = "https://sma.corp.czadd"
    #$smaPort = "9090"  #the SMA port, 9090 is the default
    <#

    Function Create-Runbook {
        #Create new repo folder
        $NewRunbook = Read-Host "Runbook name?"
        $RepoPath = $LocalRepo + "\" + $NewRunbook
        Write-Verbose "Checking repo path.($RepoPath)"
        if (test-path $RepoPath) { Throw "Runbook path exists. Try another name." }
        Else{
            #create Repo folder
            New-Item "$RepoPath" -ItemType Directory | Out-null
            #Create empty script and edit it
            New-Item "$RepoPath\$NewRunbook.ps1" -type file -force -value "Workflow $NewRunbook {`n`t`n}"
            psEdit "$RepoPath\$NewRunbook.ps1"
        }
    }

#>
<#    Function Commit-Changes {
        #Save the runbook to the repo and push to SMA
        $psISE.CurrentFile.Save()
    
        #Get a few directories
        $popD = Get-Location
        $thisRepo = Split-Path $psISE.CurrentFile.FullPath

        #Execute GIT Checkin
        CD $thisRepo
        Add-GitAll
        GIT add .
        $thisComment = Read-Host 'Enter a Comment' 
        GIT commit -m "$($THIScOMMENT)"

        CD $popd.Path
    }    
#>
<#

    Function Publish-Runbook {
        $psISE.CurrentFile.Save()
        #Get the current file name onlyu, no extension
        $RBName = [io.path]::GetFileNameWithoutExtension("$($psISE.CurrentFile.FullPath)") 
        #do a commit in case of changes
        #New-GitCommit
        #Check if the runbook exists, import new or edit existing
        If (Get-smaRunbook -WebServiceEndpoint $smaWeb -Port $smaPort | Where RunbookName -match $RBName) {
            Write-Host "Publishing existing runbook"
            Edit-SMARunbook -WebServiceEndpoint $smaWeb -Port $smaPort -Name "$RBName" -Path "$($psISE.CurrentFile.FullPath)" -Overwrite
            start-sleep -Seconds 10 
            Publish-SmaRunbook -WebServiceEndpoint $smaWeb -port $SMAport -Name "$RBName"
            Get-SmaRunbook -Id $ImportRb.RunbookID -WebServiceEndpoint $smaWeb -Port $smaPort | fl RunbookName, RunbookId, LastModifiedTime, DraftRunbookVersionID, PublishedRunbookVersionId 
        } else {
            Write-Host "Publishing new runbook"
            $ImportRb = Import-SmaRunbook -WebServiceEndpoint $smaWeb -port $smaPort -Path "$($psISE.CurrentFile.FullPath)"
            Set-SmaRunbookConfiguration -Id $ImportRb.RunbookID -LogDebug $true -LogVerbose $true -WebServiceEndpoint $smaWeb -Port $smaPort 
            Publish-SmaRunbook -Id $ImportRb.RunbookID -WebServiceEndpoint $smaWeb -port $smaPort
            Write-Host "Waiting for runbook to publish"
            start-sleep -Seconds 10 
            Edit-SmaRunbook -Id $ImportRb.RunbookID -Path $psISE.CurrentFile.FullPath -Overwrite -WebServiceEndpoint $smaWeb -Port $smaPort
            Publish-SmaRunbook -Name $RbName -WebServiceEndpoint $smaWeb -port $smaPort 
            Get-SmaRunbook -Id $ImportRb.RunbookID -WebServiceEndpoint $smaWeb -Port $smaPort | fl RunbookName, RunbookId, LastModifiedTime, DraftRunbookVersionID, PublishedRunbookVersionId 
        }

    }


#>        #Lets display a menu
        $AddonsMenu = $PsIse.CurrentPowerShellTab.AddOnsMenu
        
        
        #If( -not( $AddonsMenu.Submenus.Where({$_.Displayname -eq 'SMA'}) ) ) {
        #    $menuSMAPublishing = $psISE.CurrentPowerShellTab.AddOnsMenu.Submenus.Add("SMA",$null,$null)
        #    $menuSMAPublishing.SubMenus.Add("_Create Runbook", { Create-Runbook } , "Ctrl+Alt+R")
        #    #$menuSMAPublishing.SubMenus.Add("_Commit Changes", { Commit-Changes } , "Ctrl+Alt+N")
        #    $menuSMAPublishing.SubMenus.Add("_Publish Runbook to SMA", { Publish-Runbook } , "Ctrl+Alt+L")
        #}


        #Standard Git commands on the ISE menu
        If( -not( $AddonsMenu.Submenus.Where({$_.Displayname -eq 'GIT'}) ) ) {
            $menuSMAPublishing = $psISE.CurrentPowerShellTab.AddOnsMenu.Submenus.Add("Git",$null,$null)
            $menuSMAPublishing.SubMenus.Add("_Add all", { Add-GitAll } , $Null)  # "Ctrl+Alt+A")
            $menuSMAPublishing.SubMenus.Add("_Commit", { New-GitCommit } , $null) # "Ctrl+Alt+C")
            $menuSMAPublishing.SubMenus.Add("_Pull", { Get-GitPull } , $Null) # "Ctrl+Alt+P")
            $menuSMAPublishing.SubMenus.Add("_Push", { Push-Git } , $Null) # "Ctrl+Alt+u")
            $menuSMAPublishing.SubMenus.Add("_Push (quick)", { Push-Git -Fast } , $Null) # "Ctrl+Alt+f")
            $menuSMAPublishing.SubMenus.Add("_Status", { Get-GitState } , $Null) # "Ctrl+Alt+s")
        }
}

#endregion

#region Aliases

#Adapted from https://gist.github.com/ArnoldZokas/5578616

function Get-GitPull { git pull }
Set-Alias pull Get-GitPull -Description Git

function Get-GitCheckout($branchName) { git checkout $branchName }
Set-Alias co Get-GitCheckout -Description Git

function Remove-GitBranch($branchName) { git branch -D $branchName }
Set-Alias whack Remove-GitBranch -Description Git

function Get-GitCherryPick($branchName) { git cherry-pick $branchName }
Set-Alias cherry Get-GitCherryPick -Description Git

function Get-GitState { git status }  
Set-Alias ss Get-GitState -Description Git

#Set-Alias s get-gitstatus -Description Git #from posh-git
Set-Alias gs Write-VcsStatus -Description Git


function Get-GitPrettyLog { git log --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit }
Set-Alias lsd Get-GitPrettyLog -Description Git

function Get-GitPrettyLogNewCommits { git log origin/master..HEAD --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit }
Set-Alias wtf Get-GitPrettyLogNewCommits -Description Git

function Compare-Git { git difftool }
Set-Alias d Compare-Git -Description Git
Set-Alias gdiff Compare-Git -Description Git

function Add-GitAll { 
    #git add . | git add -u 
    git add --all
}
Set-Alias aa Add-GitAll -Description Git

function Reset-Git { git reset }
Set-Alias reset Reset-Git -Description Git

function Add-GitInteractive { git add -i }
Set-Alias ai Add-GitInteractive -Description Git

function New-GitCommit { 
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true,Position=0)][String]$Message,
        [Parameter(Mandatory=$false,Position=0)][String]$FileName
    )
    $Cmd = git commit "$FileName" -m "$message" 
    $cmd
}
Set-Alias c New-GitCommit -Description Git

function Push-Git { 
    [CmdletBinding(DefaultParametersetName='none')]
    Param( 
        [Parameter(ParametersetName='Fast',Mandatory=$false,Position=0)][Switch]$Fast, 
        [Parameter(ParametersetName='Fast',Mandatory=$true,Position=0)][String]$Message 
    )
    If( $Fast ) {
        Get-GitPull
        Add-GitAll
        start-sleep -milliseconds 500
        New-GitCommit -Message $Message
    }
    git push
}
Set-Alias ggo Push-Git -Description Git
Set-Alias push Push-Git -Description Git

Function Push-GitFast { 
    [Cmdletbinding()]
    Param( [Parameter(Mandatory=$true,Position=0)][String]$Message  )
    Push-Git -Fast -Message $Message 
}
Set-Alias pq Push-GitFast -Description Git
Set-Alias pf Push-GitFast -Description Git

Function Show-GitHistory{
    [CmdletBinding()]
    Param(
        # Filename
        [Parameter(Mandatory=$false,ValueFromPipelineByPropertyName=$true,Position=0)][String]$Filename
    )
    
    If( $Filename ){ 
        Write-Verbose "Showing history for $Filename"
        $Command = {gitk $((get-item $Filename | select -expandproperty name)) }
        Invoke-Command -ScriptBlock $Command
    }
    Else{ 
        Write-Verbose "Showing all history."
        gitk 
    }
}
Set-Alias -Name hx -Value Show-GitHistory -Description 'Git'

Function Invoke-GitRevert{
    [CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact="High")]
    Param(
        # Filename
        [Parameter(Mandatory=$false,ValueFromPipelineByPropertyName=$true,Position=0)][String]$FileName,
        # All uncommited changes
        [Parameter(Mandatory=$false,ValueFromPipelineByPropertyName=$true)][Switch]$All
    )
    
    If( $All ){
        If( -not $pscmdlet.ShouldContinue("Abandon ALL uncommitted changes. Are you sure?","Revert") ){ break }
        git checkout -- .
    }
    ElseIf( $Filename ){
        git checkout $Filename
    }
    Else{ Write-Warning "No parameters entered. Enter a file name or use the -All parameter."}
}
Set-Alias revert Invoke-GitRevert -Description Git

function Invoke-GitResetHard {
    [CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact="High")]
    Param()
    
    If( -not $pscmdlet.ShouldContinue("Are you sure? This will abandon ALL uncommitted changes.","Nuke") ){ break }

    git reset --hard
    git clean -f -d

    write-host ""
    write-host "                      __,-~~/~    `---.                  "
    Write-Host "                    _/_,---(      ,    )                 "
    write-host "                 __ /        <    /   )  \___            "
    write-host "                ====------------------===;;;==           "
    write-host "                   \/  ~ ~ ~ ~ ~ ~\~ ~)~ ,1/             "
    write-host "                   (_ (   \  (     >    \)               "
    write-host "                    \_( _ \<         >_>'                "
    write-host "                       ~ `-i' ::>/--'                    "
    write-host "                           I;|.|.|                       "
    write-host "                          <|i::|i|>                      "
    write-host "                           |[::|.|                       "
    write-host "                            ||: |                        "
    write-host " _________________________GROUND ZERO___________________ "
    write-host ""
}
Set-Alias nuke Invoke-GitResetHard -Description Git

#endregion

#region Posh-Git prompt

#function prompt
#{
#    If( Test-Administrator ) { Write-host "[ADMIN] " -ForegroundColor red -NoNewline }
#    $realLASTEXITCODE = $LASTEXITCODE
#    Write-Host($pwd.ProviderPath) -nonewline
#    Write-VcsStatus
#    $global:LASTEXITCODE = $realLASTEXITCODE
#    return "> "
#    If( $x -eq 1 ){ "x" }
#}

#endregion

export-modulemember -function * -variable * -alias * -Cmdlet *