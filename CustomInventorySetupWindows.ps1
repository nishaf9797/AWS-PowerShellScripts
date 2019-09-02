<#
.SYNOPSIS
  This Script will create a json file for Custom Inventory about the License and BillingInfo.


.DESCRIPTION
    We will create an association of this script with the ec2 instance of which LicenseInfo and BillingInfo we want to monitor through the Custom Inventory.
    The Script will run and get the desired information from the Instance and create the JSON File in the Custom Inventory Path of AWS.


.NOTES
    Version: 1.0
    Author: Nishaf Naeem
    Creation Date: 02-06-2019
    Purpose/Change: CustomInventorySetupForWindows
#>

$AWS_CONFIG_DIR = "C:\Users\Administrator\.aws"
$AWS_CONFIG_FILE = $AWS_CONFIG_DIR + "\config"
$BILLING_MAP = @{
    "bp-6ba54002"= "Windows paid license"; 
    "bp-6aa54003"="Windows + SQL Server Standard paid license";
    "bp-62a5400b"="Windows + SQL Server Enterprise paid license";
    "bp-65a5400c"="Windows + SQL Server Web  paid license";
    "bp-6ca54005"="Novell Paid Linux";
    "bp-6fa54006"="Red Hat Paid Linux";
    "bp-63a5400a"="Red Hat BYOL Linux";
    "bp-64a5400d"="RDS Oracle BYOL";
    "bp-67a5400e"="Windows BYOL";
}
Function Create-AWS-Path($region){
    if(-Not (Test-Path $AWS_CONFIG_DIR)){
        New-Item -ItemType directory -Path $AWS_CONFIG_DIR
    }
    if(-Not (Test-Path $AWS_CONFIG_FILE)){
        New-Item -ItemType file -Path $AWS_CONFIG_FILE
    }
    $content = "[default]`r`nregion = " + $region + "`r`noutput = json"
    Set-Content -Path $AWS_CONFIG_FILE -Value $content
}

Function Get-Content($instance_details, $billinginfo){
    $license_info = "AWS Managed License"
    if($instance_details[4].Trim() -eq '[]'){
        $license_info = "Not AWS Managed License"
    }
    $image_id = $instance_details[3].split('\"')[1]
    $data = @{"InstanceId"=$instance.instanceId; "ImageId"=$image_id; "LicenseInfo"=$license_info; "BillingInfo"=$billinginfo} | ConvertTo-Json
    $content = "{`"SchemaVersion`" : `"1.0`", `"TypeName`": `"Custom:InstanceInfo`", `"Content`": $data}"
    return $content
}

Function Write-To-File($content){
    $filepath = "C:\ProgramData\Amazon\SSM\InstanceData\" + $instance.instanceId + "\inventory\custom\CustomInstanceInfo.json"
    if (-NOT (Test-Path $filepath)) {
        New-Item $filepath -ItemType file
    }
    Set-Content -Path $filepath -Value $content
}

$instance = Invoke-RestMethod -uri http://169.254.169.254/latest/dynamic/instance-identity/document
Create-AWS-Path -region $instance.region
$instance_details = aws ec2 describe-instances --instance-ids $instance.InstanceId --region $instance.region --query "Reservations[*].Instances[*].[ImageId, ProductCodes]"
$content = Get-Content -instance_details $instance_details -billinginfo $BILLING_MAP[$instance.billingProducts[0]]
Write-To-File -content $content

