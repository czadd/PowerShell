<#
.Synopsis
   Expand a VHD on a VM.
.DESCRIPTION
   This script will expand a VHD on a VM. Optionally, it will expand the vhd file via SCVMM. In order for this to work properly, the volume label on the VM must match the vhd name in SCVMM. If they don't match, there will be no way to determine which VHD to expand and an error will be thrown.
.EXAMPLE
   PS:> Resize-VmDisk.ps1 -Computername Somecomputer -DriveLetter F -SizeGb 55 -ExpandVmmVolume 

   Expands the VHD file via SCVMM, then remotes to the VM to expand the disk within the OS.
.EXAMPLE
   PS:> Resize-VmDisk.ps1 -Computername Somecomputer -DriveLetter F

   Remotes to the VM to expand the disk within the OS. Use this if you have already manually expanded the VHD.
.EXAMPLE
   PS:> Resize-VmDisk.ps1

   Script will prompt for Computername and Driveletter.  It will only expand the disk within the OS. To resize the .vhd, use the -SizeGB parameter.
.NOTES
   Created 5/11/16 CRS
#>

#Requires -Modules virtualmachinemanager

[CmdletBinding(DefaultParameterSetName='NoVMM')]
Param(
    # Server name
    [Parameter(Mandatory=$true ,ValueFromPipelineByPropertyName=$true)][String]$ComputerName,
    # Drive letter
    [Parameter(Mandatory=$true ,ValueFromPipelineByPropertyName=$true)][String]$DriveLetter,
    # Use VMM to expand the VHD
    [Parameter(Mandatory=$false,ValueFromPipelineByPropertyName=$true,ParameterSetName='UseVmm')][Switch]$ExpandVmmVolume=$false,
    # New size in GB
    [Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true,ParameterSetName='UseVmm')][Int]$SizeGb,
    # Windows version. Leave this alone. Different methods are used to expand the disk for different versions of Windows.
    [Parameter(Mandatory=$false,ValueFromPipelineByPropertyName=$true)][System.Version]$Winversion='6.3.9600' #2012 R2
)


Begin{
    If( $SizeGb ){ $ExpandVmmVolume = $true }
    Try{
        If( -not (get-module virtualmachinemanager -ErrorAction SilentlyContinue -Verbose:$false) ){ Import-Module virtualmachinemanager -ErrorAction Stop -Verbose:$False }
    }
    Catch{
        Throw "Cannot load VMM module"
    }
}

Process{
    $CimSession = New-CimSession -ComputerName $ComputerName -Verbose:$False -ErrorAction Stop

    [System.Version]$ServerWinVersion = Get-CimInstance -CimSession $CimSession -ClassName Win32_OperatingSystem | Select -ExpandProperty Version
    $Volume = Get-CimInstance win32_logicaldisk -CimSession $CimSession | where DeviceId -eq ($DriveLetter  + ":") 
    $Vhd = Get-SCVirtualHardDisk -VM $ComputerName | Where name -eq $Volume.Volumename

    If( -not $Vhd ){
        $CimSession | Remove-CimSession
        Throw "No VhD found with label `"$($Volume.Volumename)`"."
    }
    Else{ Write-Verbose "Matching VHD found $($vhd.Name)" }

    If( $Vhd.VHDType -ne 'DynamicallyExpanding' ){ Throw "VHD is not dynamically expanding."}
    If( $Vhd.VHDFormatType -eq 'vhd' ){ Throw "VHD format cannot be resized by this script."}
    Else{ Write-Verbose "VHDX format found." }

    If( $ExpandVmmVolume ){
        $ScVolume = get-vm $ComputerName | Get-SCVirtualDiskDrive | Where virtualharddisk -match $Volume.Volumename
        If( $Scvolume.count -lt 1 ){ Throw "No HDD found in SCVMM for volume name $($Volume.FileSystemLabel)" }
        ElseIf( $Scvolume.count -gt 1 ){ Throw "Multiple VHDs found matching $($Volume.FileSystemLabel)" }
        Else{ Write-Verbose "SCVMM volume found. $($Scvolume.VirtualHardDisk)" }
        Expand-SCVirtualDiskDrive -VirtualDiskDrive $ScVolume -VirtualHardDiskSizeGB $SizeGb -ErrorAction Stop | Out-null
    }

    If( $ServerWinVersion -lt $Winversion ){ 
        Write-Verbose "Expanding Windows 2008 disk via DiskPart"
        #In 2008 it's easiest to iterate all disks and extend them. I can't figure out a good way to get the partition ID of the disk to expand just the one.
        Invoke-command -ComputerName $ComputerName -ScriptBlock {
        "rescan" | Diskpart
        'list disk' | diskpart | Where { $_ -match 'disk (\d+)\s+online\s+\d+ .?b\s+\d+' } | Foreach {
            $disk = $matches[1]

            "select disk $disk", "list partition" | diskpart | Where { $_ -match 'partition (\d+)' } | Foreach{
                $matches[1] } | Foreach {
                    "select disk $disk", "select partition $_", "extend" | diskpart | Out-null
                }
            }
        }
    }
    Else{
        Write-Verbose "Expanding Windows 2012 Disk"
        $Partition = get-partition -DriveLetter $DriveLetter -CimSession $CimSession
        Write-Verbose "Partition - $($Driveletter): $( "{0:n2}" -f ($Partition.size / 1gb)) GB"
        $Size = $Partition | Get-PartitionSupportedSize -CimSession $CimSession
        Write-verbose "Max size: $("{0:n2}" -f ($Size.SizeMax / 1gb)) GB."
        Update-HostStorageCache -CimSession $CimSession
        Try{ $Partition | Resize-Partition -Size $Size.SizeMax -CimSession $CimSession -ErrorAction Stop  }
        Catch{ 
            If( $_.Exception -match 'size not supported'){ Throw "Unable to resize. Check disk size and ensure it has been expanded." } 
        }
        $NewPartition = $Partition | Get-Partition -CimSession $CimSession
        #Write-Verbose "New size $("{0:n2}" -f ($NewPartition.Size / 1gb)) GB."
        #Write-Output "Resized $ComputerName $($DriveLetter): $($Volume.FileSystemLabel) $("{0:n2}" -f ($Partition.Size / 1gb))GB -> $("{0:n2}" -f ($NewPartition.Size / 1gb))GB"
    }

    $NewPartition = Get-CimInstance -CimSession $CimSession -ClassName win32_logicaldisk | Where DeviceId -eq ($DriveLetter + ":")
    $NewPartition | Select @{Name="DriveLetter";Expression={$_.DeviceId}},@{Name="OrigSizeGb";Expression={"{0:n2}" -f ($volume.Size / 1gb)}},@{Name="NewSizeGB";Expression={ "{0:n2}" -f ($_.Size / 1gb)}} 
    }
End{
    $CimSession | Remove-CimSession
}