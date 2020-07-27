Function Get-CsvFreespace{
<#
.SYNOPSIS 
  Get Cluster free space.
.DESCRIPTION 
  Get cluster free space. Including a computer name will cause the script to "guess" which cluster to query.
  The guess will be used as the default from the menu.
.EXAMPLE 
  PS C:> .\Get-CsvFreespace.ps1 -cluster cluster01 | Ft -auto
  Tell the script to check CSV sizes for the cluster named cluster01. 
.EXAMPLE 
  PS C:> .\Get-CsvFreespace.ps1 -comutername ClHost01 | Ft -auto
  Tell the script to get CSV sizes for the cluster that ClHost01 is a member node of.
.EXAMPLE 
  PS C:> .\Get-CsvFreespace.ps1 | ft -auto
  Show a list of clusters and choose the cluster from the menu.
.EXAMPLE 
  PS C:> .\Get-CsvFreespace.ps1 -all | ft -auto
  Get CSV sizes for all CSVs on all clusters.
.NOTES 
  CRS 08/04/2014
  The script is filtered to only list clusters in the Servers OU.
#>


[CmdletBinding()]
Param(
[Parameter( Mandatory=$false, Position=0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)][Alias("cluster")][String]$ClusterName,
[Parameter( Mandatory=$false, Position=1, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)][Alias("Computer","Server")][String]$ComputerName,
[Parameter( Mandatory=$false, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)][Switch]$ShowMenu,
[Parameter( Mandatory=$false, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)][Switch]$All,
[Parameter( Mandatory=$false, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)][ValidateSet("Human","Script")][String]$Output='Human'
)

Begin{
    Function Show-ClusterMenu ($items,$default) {
        $menu = @{}
        Write-Host "Choose a cluster`n" -foregroundcolor green
        for ($i=1;$i -le $items.count; $i++) {
            #If( ! ( $($items[$i-1].basename) -match "menu" ) ) {
            Write-Host "$i.`t$($items[$i-1])"
            $menu.Add($i,($items[$i-1]))
            #}
        }

        If( $Default ){
            [int]$ans = Read-Host "Choose a cluster (blank for $default)"
            If( !( $ans ) ) { $selection = $default }
            Else{ $selection = $menu.Item($ans) }
            Write-Output $selection
        }
        Else{
            [int]$ans = Read-Host "Choose a cluster (blank to quit)"
            If( !( $ans ) ) { break }
            Else{ $selection = $menu.Item($ans) }
            Write-Output $selection    
        }
    } #END Function show-menu

    If( $all ){
        Write-Verbose "Get CSV sizes for all clusters"
        $ClusterList = get-cluster -domain corp.czadd |  Where { (get-adcomputer $_.name | Where DistinguishedName -match 'OU=Virtual Hosts,OU=Servers,DC=corp,DC=czadd' | select -ExpandProperty DistinguishedName) -match 'OU=Servers' } | sort name -Unique 
        $Cluster = Foreach( $Clust in $ClusterList ){
            $AdComputerObject = Get-AdComputer $Clust.Name
            If( $Clust.name -eq ($AdComputerObject.DNSHostName -replace '.corp.czadd','') ){ [PsCustomObject]@{Name=$Clust.Name} } 
            Else{ [PsCustomObject]@{Name=($AdComputerObject.DNSHostName -replace '.corp.czadd','') } }
        }
    }
    ElseIf( $ClusterName ){ #If a clustername was included as a parameter
        Write-Verbose "Validate entered clustername"
        If( ($Clustername -notmatch 'clust') -and ($ClusterName -ne 'Ignoreme') ){ $ClusterName = $ClusterName + 'cluster' }
        $Cluster = Get-Cluster $ClusterName -ErrorAction SilentlyContinue
        If( !( $Cluster)  ) { Write-Error "$ClusterName is not a valid cluster" ; break}
    } 
    ElseIf( $ComputerName ){
        Write-Verbose "Select by computername"
        $ClusterList = get-cluster -domain corp.czadd |  Where { (get-adcomputer $_.name | select -ExpandProperty DistinguishedName) -match 'OU=Servers' } | sort name -Unique 
        
        Foreach( $ClusterItem in $ClusterList ){
            $nodes = get-clusternode -cluster $ClusterItem -ErrorAction SilentlyContinue
            If( $nodes -contains $ComputerName ){ Write-Verbose "Match found for $Clusteritem.name $ComputerName" ; $Cluster = $ClusterItem }
            Else { Write-Verbose "No match for $ClusterItem.name / $computername" }
        }
        If( $Cluster ) { Write-Verbose "Our cluster: $Cluster.name" }
        Else{  Write-Error -Message "$computername is not a cluster node." }
    }
    ElseIf( $ShowMenu -or (! $ComputerName -and ! $ClusterName) ){
        Write-Verbose "Show cluster menu"
        $ClusterList = get-cluster -domain corp.czadd |  Where { (get-adcomputer $_.name | select -ExpandProperty DistinguishedName) -match 'OU=Servers' } | sort name -Unique 
        $ClusterName = Show-ClusterMenu -items $ClusterList  | select -ExpandProperty name 
        $Cluster = get-cluster $ClusterName
    }
    Else { Throw "An unexpected error occurred. $error" }
}


Process{
    Write-Verbose "Checking CSV sizes"
    $ClusterSharedVolumes = {}
    $ClusterSharedVolumes = @()

    Foreach( $Clust in $Cluster ){
        Write-Verbose "Cluster: $($Clust.name)"
        Foreach( $Csv in  (Get-ClusterSharedVolume -Cluster $Clust.name -ErrorAction SilentlyContinue) ){
            Write-Verbose $Csv.Name
            $CsvSize = $csv | select -ExpandProperty sharedvolumeinfo | select -ExpandProperty Partition | select -ExpandProperty size 
            $CsvUsed = $csv | select -ExpandProperty sharedvolumeinfo | select -ExpandProperty Partition | select -ExpandProperty UsedSpace
            $CsvFree = $CsvSize - $CsvUsed
            $CsvFreePct = $csvFree / $CsvSize * 100
            $CsvObject = New-Object –TypeName PSObject
            $CsvObject | Add-Member –MemberType NoteProperty –Name Cluster –Value ($Clust | select -expandproperty name )
            $CsvObject | Add-Member –MemberType NoteProperty –Name Name –Value ($csv | select -expandproperty sharedvolumeInfo | select -ExpandProperty FriendlyVolumeName)
            $CsvObject | Add-Member –MemberType NoteProperty –Name 'Size (GB)' –Value ( "{0:n2}" -f ( $CsvSize / 1gb) )
            $CsvObject | Add-Member –MemberType NoteProperty –Name 'Free (GB)' –Value ( "{0:n2}" -f ($CsvFree / 1gb) )
            $CsvObject | Add-Member –MemberType NoteProperty –Name "Free %" –Value ( "{0:n2}" -f ($CsvFree / $CsvSize  * 100))
            $CsvObject | Add-Member –MemberType NoteProperty –Name OwnerNode –Value $Csv.OwnerNode
            $ClusterSharedVolumes += $CsvObject
        } 
    }   

    If( $output -eq 'Human' ){ $ClusterSharedVolumes | sort Cluster, Name | ft -AutoSize }
    Else{ $ClusterSharedVolumes | sort Cluster, Name }
}

}

export-modulemember -function * -variable * -alias * -Cmdlet *