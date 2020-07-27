<#
.Synopsis
   Gets files sizes for DFSR staging sizing. 
.DESCRIPTION
   Gets largest 32 files in a directory and displays the combined size of the files. Use this to determine DFSR sizing.
.EXAMPLE
   PS:> Get-DfsrSizing.ps1 -Path \\server.corp.czadd\d$\SomeShare
   Get sizing for the path provided
.EXAMPLE
  PS:> Get-DfsrSizing.ps1 -path 'd:\blah','e:\two'
  Get sizing for multiple paths
.EXAMPLE
  PS:> Get-DfsrSizing.ps1 -path (ls E:\Somepath).FullName
  Get sizing for all directories in E:\Somepath
#>

[CmdletBinding()]
Param
(
    # Path to replicated directory
    [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true, Position=0)][ValidateScript({Test-Path $_})][String[]]$Path,
    # How many files?
    [Parameter(Mandatory=$false)][Int]$Count=32,
    # Use the ListFiles parameter to display a list of the largest files
    [Parameter(Mandatory=$false)][Switch]$ListFiles=$true
)

Foreach( $Dir in $Path ){
    $filelist = gci -Path $Dir -Recurse -Exclude DfsrPrivate -ErrorAction SilentlyContinue
    $bigfiles = $filelist | Sort-Object length -Descending | Select-Object -first $Count

    If( $ListFiles ){ 
        Foreach( $File in ( $bigfiles | Sort Length -Descending) ){
            $File  | Select name, @{l='SizeMb';e={"{0:n2}" -f ($File.length /1mb)} } 
        }
    }
    
    #$SizeMb = [math]::floor( (($bigfiles | measure-object -property length -sum).sum /1gb) + 1 ) * 1024 #Round down to the nearest GB, then add 1 GB and display in MB for easy pasting into DFS console
    $SizeMb = [math]::ceiling( (($bigfiles | measure-object -property length -sum).sum /1gb) ) *1024
    #$SizeMb =     [math]::ceiling(($bigfiles | measure-object -property length -sum).sum /1mb)
    [pscustomobject]@{Path=$Dir;SizeMb=$SizeMb}

}
