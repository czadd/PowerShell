<#
.Synopsis
   Back up GPOs.
.DESCRIPTION
   Back up GPOs to file.  By default, the script will only back up GPOs that have been changed since the last backup. It parses the ModifiedTime property from each GPO's gpreport.xml file to determine the latest backup. Use the -All switch to force backup of all GPOs.
.EXAMPLE
   PS:> Backup-RecentGPO.ps1
   Backs up any GPOs that have not been backed up to the default directory.
.EXAMPLE
   PS:> Backup-RecentGPO.ps1 -All -BackupRootPath '\\corp.co\sharename\subfolder\subfolder2'
   Backs up all GPOs regardless of last modified date to the specified path
.EXAMPLE
   PS:> Backup-RecentGPO.ps1 -datetime (get-date).adddays(-30) -BackupRootPath '\\corp.co\sharename\last30'
   Backs up all GPOs changed within the lasst 30 days to the specified path
#>

[CmdletBinding()]
Param(
    # Path to GPO backups
    [Parameter(Mandatory=$false,ValueFromPipelineByPropertyName=$true,Position=0)][String]$BackupRootPath = '\\corp.czadd\share\GPO Backup',
    # Use a date to back up all GPOs modified after a specific datetime
    [Parameter(Mandatory=$false,ValueFromPipelineByPropertyName=$true)][DateTime]$DateTime,
    # Comment or reason. Use this to explain if any changes were made.
    [Parameter(Mandatory=$false,ValueFromPipelineByPropertyName=$true)][String]$Comment,
    # Select -All to backup all GPOs regardless of last modified date
    [Parameter(Mandatory=$false,ValueFromPipelineByPropertyName=$true)][Switch]$All
)

$TimeStamp = get-date -Format yyyyMMdd_HHmm
If( -not (test-path $BackupRootPath) ){ New-Item $BackupRootPath -ItemType Directory -Confirm }
$BackupPath = Join-Path $BackupRootPath $TimeStamp

Write-Verbose "Parsing backup times from existing backup XML."
$Backedup = Foreach( $BackupXMLfile in ($BackupRootPath | Get-ChildItem -Recurse -Include 'gpreport.xml') ){
    [xml]$BackupXML = get-content $BackupXMLfile
    [PsCustomObject]@{Name=$BackupXML.GPO.Name;Identifier=$BackupXML.GPO.Identifier.Identifier.'#text';ModifiedTime=$BackupXML.GPO.ModifiedTime}
}
$NewestBackup = get-date ($Backedup | sort Modifiedtime | select -last 1 -ExpandProperty ModifiedTime)
Write-Verbose "Newest backup: $($Backedup | sort Modifiedtime | select -last 1 | Select -expandproperty name) at $NewestBackup"

Write-Verbose "Getting GPOs."
If( $All ){ $GPO = get-gpo -All }
ElseIf( $DateTime ){ $GPO = get-gpo -All | Where ModificationTime -gt $DateTime.ToUniversalTime() }
Else{ $GPO = get-gpo -All | Where ModificationTime -gt $NewestBackup.ToUniversalTime() }

If( $GPO.count -gt 0 ){
    Write-Output "Backing up $($GPO.count) GPOs:"
    If( -not (Test-Path $BackupPath) ){ New-Item -Path $BackupPath -ItemType Directory | out-null }
    If( $Comment ){ 
        $CommentText = "$Comment`n$($Env:UserName) $(get-date)`n`nGPO(s):`n"
        Foreach( $G in $GPO ){ $CommentText = $CommentText + $g.Displayname }
        $CommentText | Out-File (Join-Path $BackupPath 'Comments.txt')
    }
    $GPO | Backup-GPO -Path $BackupPath | Select -ExpandProperty Displayname
}
Else{ Write-Output "No GPOs to backup." }
