<#
.SYNOPSIS
  This Script add Drive Name tag to the Volumes attached to an Instance.



.DESCRIPTION
   This Script add Drive Name tag to the Volumes attached to an Instance.
   For Windows it will get all the Drive Names like C, D, E etc. and add this Drive Letter to the Volume associated to it
   Same is the case for the linux, it will get the directory name on which the volume is mounted and tag that volume with that directory name.  

.NOTES
    Version: 1.0
    Author: Nishaf Naeem
    Creation Date: 02-06-2019
    Purpose/Change: Tag Volume with Drive Name.
#>

function Get-EC2InstanceMetadata($Path){
  return (Invoke-WebRequest -Uri "http://169.254.169.254/latest/$Path" -UseBasicParsing).Content 
}

function Convert-SCSITargetIdToDeviceName($SCSITargetId) {
  If ($SCSITargetId -eq 0) {
    return "sda1"
  }
  $deviceName = "xvd"
  If ($SCSITargetId -gt 25) {
    $deviceName += [char](0x60 + [int]($SCSITargetId / 26))
  }
  $deviceName += [char](0x61 + $SCSITargetId % 26)
  return $deviceName
}

function Get-BlockDeviceMappings($InstanceId, $Region){
$res = aws ec2 describe-instances --instance-ids $InstanceId --region $Region
$res = @"
$res
"@
$res = $res | ConvertFrom-Json
return $res.Reservations[0].Instances[0].BlockDeviceMappings
}

function Get-VolumesInfo(){
    $volumesInfo = @()
    Try {
      $InstanceId = Get-EC2InstanceMetadata "meta-data/instance-id"
      $AZ = Get-EC2InstanceMetadata "meta-data/placement/availability-zone"
      $Region = $AZ.Remove($AZ.Length - 1)
      $BlockDeviceMappings = Get-BlockDeviceMappings -InstanceId $InstanceId -Region $Region
      $VirtualDeviceMap = @{}
      (Get-EC2InstanceMetadata "meta-data/block-device-mapping").Split("`n") | ForEach-Object {
        $VirtualDevice = $_
        $BlockDeviceName = Get-EC2InstanceMetadata "meta-data/block-device-mapping/$VirtualDevice"
        $VirtualDeviceMap[$BlockDeviceName] = $VirtualDevice
        $VirtualDeviceMap[$VirtualDevice] = $BlockDeviceName
      }
    }
    Catch {
      Write-Host "Could not access the AWS API, therefore, VolumeId is not available. 
    Verify that you provided your access keys." -ForegroundColor Yellow
    }
    Get-disk | ForEach-Object {
      $DiskDrive = $_
      $Disk = $_.Number
      $Partitions = $_.NumberOfPartitions
      $EbsVolumeID = $_.SerialNumber -replace "_[^ ]*$" -replace "vol", "vol-"
      Get-Partition -DiskId $_.Path | ForEach-Object {
        if ($_.DriveLetter -ne "") {
          $DriveLetter = $_.DriveLetter
          $VolumeName = (Get-PSDrive | Where-Object {$_.Name -eq $DriveLetter}).Description
        }
      } 

      If ($DiskDrive.path -like "*PROD_PVDISK*") {
        $BlockDeviceName = Convert-SCSITargetIdToDeviceName((Get-WmiObject -Class Win32_Diskdrive | Where-Object {$_.DeviceID -eq ("\\.\PHYSICALDRIVE" + $DiskDrive.Number) }).SCSITargetId)
        $BlockDeviceName = "/dev/" + $BlockDeviceName
        $BlockDevice = $BlockDeviceMappings | Where-Object { $BlockDeviceName -like "*"+$_.DeviceName+"*" }
        $EbsVolumeID = $BlockDevice.Ebs.VolumeId 
        $VirtualDevice = If ($VirtualDeviceMap.ContainsKey($BlockDeviceName)) { $VirtualDeviceMap[$BlockDeviceName] } Else { $null }
      }
      ElseIf ($DiskDrive.path -like "*PROD_AMAZON_EC2_NVME*") {
        $BlockDeviceName = Get-EC2InstanceMetadata "meta-data/block-device-mapping/ephemeral$((Get-WmiObject -Class Win32_Diskdrive | Where-Object {$_.DeviceID -eq ("\\.\PHYSICALDRIVE"+$DiskDrive.Number) }).SCSIPort - 2)"
        $BlockDevice = $null
        $VirtualDevice = If ($VirtualDeviceMap.ContainsKey($BlockDeviceName)) { $VirtualDeviceMap[$BlockDeviceName] } Else { $null }
      }
      ElseIf ($DiskDrive.path -like "*PROD_AMAZON*") {
        $BlockDevice = ""
        $BlockDeviceName = ($BlockDeviceMappings | Where-Object {$_.ebs.VolumeId -eq $EbsVolumeID}).DeviceName
        $VirtualDevice = $null
      }
      Else {
        $BlockDeviceName = $null
        $BlockDevice = $null
        $VirtualDevice = $null
      }
      $volumesInfo += New-Object PSObject -Property @{
        Disk          = $Disk;
        Partitions    = $Partitions;
        DriveLetter   = If ($DriveLetter -eq $null) { "N/A" } Else { $DriveLetter };
        EbsVolumeId   = If ($EbsVolumeID -eq $null) { "N/A" } Else { $EbsVolumeID };
        Device        = If ($BlockDeviceName -eq $null) { "N/A" } Else { $BlockDeviceName };
        VirtualDevice = If ($VirtualDevice -eq $null) { "N/A" } Else { $VirtualDevice };
        VolumeName    = If ($VolumeName -eq $null) { "N/A" } Else { $VolumeName };
      }
    }
    return $volumesInfo, $Region, $InstanceId;
}

function AttachTagsToVolumes(){
    $volumesInfo, $Region, $InstanceId = Get-VolumesInfo
    foreach($volume in $volumesInfo){
    	$volume.EbsVolumeId
        $drive_letter = $volume.DriveLetter
        $drive_letter
        aws ec2 create-tags --resources $volume.EbsVolumeId --region=$Region --tags "Key=DeviceName,Value=$drive_letter"
   }
}

AttachTagsToVolumes