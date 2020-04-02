param (
[string] $region = "us-east-1",
[string] $subnetid
)

import-module "C:\Program Files (x86)\AWS Tools\PowerShell\AWSPowerShell\AWSPowerShell.psd1"

Set-DefaultAWSRegion($region)

$nonCompliantInstances = [System.Collections.ArrayList]@()

# Obtain a list of all instances with the Environment tag set.
$instancesGood = @{}
$filter = New-Object Amazon.EC2.Model.Filter -Property @{Name = "tag-key"; Values = "Environment"}
$reservations = Get-Ec2Instance -Filter $filter
foreach ($instance in $reservations.instances) {
	$instancesGood.Add($instance.InstanceId, 1)
}

Write-Host "Compliant instances found: " $instancesGood.count

# Obtain a list of all instances.
$vpcFilter = New-Object Amazon.EC2.Model.Filter -Property @{Name = "subnet-id"; Values = $subnetid}
$reservations = Get-Ec2Instance -Filter $vpcFilter
Write-Host "All instances: " $reservations.instances.count
foreach ($instance in $reservations.instances) {
	if ($instancesGood.ContainsKey($instance.InstanceId) -eq $false) {
		[void]$nonCompliantInstances.Add($instance.InstanceId)
	}
}

# Terminate all non-compliant instances.
if ($nonCompliantInstances.count -gt 0) {
	Write-Host "Non-compliant instances found: " $nonCompliantInstances.count
	Remove-EC2Instance -Force -InstanceId $nonCompliantInstances
	Write-Host "Instances terminated."
} else {
	Write-Host "No non-compliant instances found."
}
