<#
.Synopsis
   This is a quick translation of git commands to PowerShell functions with short aliases.  
.NOTES
   I can't remember where I downloaded the original, but I will give credit if I can find it.
.FUNCTIONALITY
   The functionality that best describes this cmdlet
.NOTES
   Author: Chad R. Smith (czadd)
.LINK
   https://github.com/czadd/PowerShell
#>

function GitPull { git pull }
Set-Alias p GitPull

function GitCheckout($branchName) { git checkout $branchName }
Set-Alias co GitCheckout

function GitDeleteBranch($branchName) { git branch -D $branchName }
Set-Alias whack GitDeleteBranch

function GitCherryPick($branchName) { git cherry-pick $branchName }
Set-Alias cherry GitCherryPick

function GitStatus { git status }
Set-Alias s GitStatus

function GitPrettyLog { git log --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit }
Set-Alias lsd GitPrettyLog

function GitPrettyLogNewCommits { git log origin/master..HEAD --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit }
Set-Alias wtf GitPrettyLogNewCommits

function GitDiff { git difftool }
Set-Alias d GitDiff

function GitAddAll { git add . | git add -u }
Set-Alias aa GitAddAll

function GitAddInteractive { git add -i }
Set-Alias ai GitAddInteractive

function GitCommit { 
    [Cmdletbinding()]
    Param( [Parameter(Mandatory=$true,Position=0)][String]$Comment )
    git commit -m "$Comment" 
}
Set-Alias c GitCommit

function GitPush { git push }
Set-Alias pu GitPush

function GitReset { git reset }
Set-Alias ua GitReset

function GitResetHard {
    git reset --hard
    git clean -f -d

write-host ""
write-host "                     __,-~~/~    `---.                   "
Write-Host "                   _/_,---(      ,    )                  "
write-host "                __ /        <    /   )  \___             "
write-host "               ====------------------===;;;==            "
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
Set-Alias nuke GitResetHard

# Load posh-git example profile
#. '\\vmware-host\Shared Folders\Documents\WindowsPowerShell\Modules\posh-git\profile.example.ps1'
