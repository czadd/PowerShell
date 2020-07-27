<#
.SYNOPSIS
   Gets a list of all the folder targets in the Domain Namespace.
.DESCRIPTION
   Gets a list of all the folder targets in the Domain Namespace. Adapted from http://britv8.com/powershell-get-list-of-all-folder-targets-in-domain-namespace/
.EXAMPLE
   PS:> Get-DfsnAllFolderTargets.ps1
   Shows all folder targets. Use Out-Gridview or export to CSV for easy viewing.
.EXAMPLE
   PS:> Get-DfsnAllFolderTargets.ps1 -Path \\corporate.co\public\stuff
   Shows folder target for a specific DFS folder.
.NOTES
   Csmith 8/9/2018
#>
#Requires -modules DFSN

[CmdletBinding()] 
Param(
    # Path to folder. E.g. \\corporate.co\public\stuff. 
    [Parameter(Mandatory=$false,ValueFromPipelineByPropertyName=$true,Position=0)][ValidateScript( {Test-path $_} )][String]$Path
)

If( -not $Path ){
    #Get a list of all Namespaces in the Domain
    Write-Host "Getting List of Domain NameSpaces"
    $RootList = Get-DfsnRoot -ErrorAction SilentlyContinue 
 
    #Get a list of all FolderPaths in the Namespaces
    Write-Host "Getting List of Domain Folder Paths"
    $FolderPaths = foreach ($item in $RootList){
        Get-DfsnFolder -Path "$($item.path)\*" -ErrorAction SilentlyContinue
    }
}
Else{ $FolderPaths = Get-DfsnFolder -Path $Path }
Write-Verbose "$($FolderPaths.Count) folder paths"
 
#Get a list of all Folder Targets in the Folder Paths, in the Namespaces"
Write-Host "Getting List of Folder Targets"
$FolderTargets = foreach ($item in $FolderPaths){
    Get-DfsnFolderTarget -Path $item.Path    
}
Write-Verbose "$($FolderTargets.Count) folder targets"

$FolderTargets | Sort namespacepath, path | export-csv d:\fld.csv -NoTypeInformation
