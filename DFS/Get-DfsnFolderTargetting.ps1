<#
.SYNOPSIS
   This script shows targets of DFS shares.
.DESCRIPTION
   This script shows targets of DFS shares. By default all shares and targets will be shown. It can be filtered to show only specific targets or shares.
.EXAMPLE
   PS:> Get-DfsnFolderTargetting.ps1
   Shows all DFS folders and their targets
.EXAMPLE
   PS:> Get-DfsnFolderTargetting.ps1 -Share 'groupshares\blah'
   Shows all targets of the \\corporate.co\groupshares\blah share. Note this is a "like" so it doesn't have to be an exact match.
.EXAMPLE
   PS:> Get-DfsnFolderTargetting.ps1 -Target srv1
   Shows all shares hosted on the srv1 server. Note this is a "like" so it doesn't have to be an exact match.
.NOTES
   csmith 5/3/2019
#>
#Requires -modules DFSN

[CmdletBinding()] 
Param(
    # Folder share namespace
    [Parameter(Mandatory=$false,ValueFromPipelineByPropertyName=$true)][String]$Share,
    # Server target
    [Parameter(Mandatory=$false,ValueFromPipelineByPropertyName=$true)][String]$Target
)

$DfsnRoot = Get-DfsnRoot -ErrorAction SilentlyContinue

$DfsnFolderTarget = Foreach( $Root in $DfsnRoot ){
    $Folder = Get-DfsnFolder -Path "$($Root.Path)\*" -ErrorAction SilentlyContinue
    $Folder | Get-DfsnFolderTarget
}


If($Share){
    If( $Share -match '\\' ){ $Share = $Share -replace "\\", "\\" }
    $DfsnFolderTarget | where Path -match $Share | Select Path, TargetPath
}
ElseIf($Target){
    $DfsnFolderTarget | Where TargetPath -match $Target | Select Path, TargetPath
}
Else{
    $DfsnFolderTarget | Select Path, TargetPath
}
