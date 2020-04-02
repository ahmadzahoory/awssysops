# stopinator.ps1 - stop or start all instances by tag value
#
# USAGE:
# stopinator.ps1 [-tags ["name=value;name2=value2"]] [-exclude]
#
# -tags: A list of semicolon-separated name/value pairs, with pair name and value delimited by an equals sign. The script converts
# this simplified tag format into the format expected by the Get-Ec2Instance Powershell cmdlet for tag Filters.
#
# -exclude: Switch parameter. If present, excludes the current instance from being stopped.
#
# -start: Switch parameter. Causes instances to be started rather than stopped. Used for bringing up powered-down instances
# when you are ready to use them again. If not included, default behavior is to stop instances.

param (
[string] $tags = $null,
[switch] $exclude,
[switch] $start
)

import-module "C:\Program Files (x86)\AWS Tools\PowerShell\AWSPowerShell\AWSPowerShell.psd1"

# If $exclude is set, obtain the current instance ID from metadata.
$currInstId = ""
if ($exclude) {
	try {
		$currInstId = (new-object net.webclient).DownloadString('http://169.254.169.254/latest/meta-data/instance-id')
		write-host "Excluding current instance ("$currInstId") from stopinator operations..." "`n"
		} catch [Exception] {
			write-host "-exclude parameter was used, but current computer has no running meta-data service. -exclude is only supported on Amazon EC2 instances."
		}
}

# Iterate through each region.
foreach ($region in Get-AwsRegion) {
	Set-DefaultAWSRegion($region.Region)
	write-host "Region is" $region.Region

	# Build tag filter from -tag name=value pairs.
	$tagsColl = [System.Collections.ArrayList]@()
	if (![string]::IsNullOrEmpty($tags)) {
		foreach ($pair in $tags.Split(";")) {
			$nameVal = $pair.Split("=")
			$filter = New-Object Amazon.EC2.Model.Filter -Property @{Name = "tag:" + $nameVal[0]; Values = $nameVal[1]}
			[void]$tagsColl.Add($filter)
		}
	}

	$instanceIds = [System.Collections.ArrayList]@()

	# Find resources with the specified tag.
	try {
            $Ec2Instances= Get-Ec2Instance -Filter $tagsColl
        } catch [Exception]{
            continue
        }
	foreach ($reservation in $Ec2Instances) {
		foreach ($instance in $reservation.Instances) {
			# Don't kill us! We're busy here!!
			if ($start -ne $true -and $exclude -and $instance.InstanceId -eq $currInstId) {
				write-host "`tExcluding instance" $instance.InstanceID
			} else {
			  # Behave different depending on whether we're starting or stopping instances.
				if ($start -eq $false) {
					if ($instance.State.Code -eq 16) {
						write-host "`tFound instance" $instance.InstanceId
						[void]$instanceIds.Add($instance.InstanceId)
					} else {
						write-host "`tInstance" $instance.InstanceId " - already stopped"
					}
				} else {
					if ($instance.State.Code -eq 80) {
						write-host "`tFound instance" $instance.InstanceId
						[void]$instanceIds.Add($instance.InstanceId)
					} else {
						write-host "`tInstance" $instance.InstanceId " - not a stopped instance"
					}
				}
			}
		}
	}

	# Stop or start all identified instances.
	if ($start -eq $true) {
		if ($instanceIds.Count -gt 0) {
			write-host "Starting all identified instances..."
			$stopResult = Start-Ec2Instance $instanceIds
		} else {
			write-host "`tNo instances to start in region"
		}
	} else {
		if ($instanceIds.Count -gt 0) {
			write-host "Stopping all identified instances..."
			$stopResult = Stop-Ec2Instance $instanceIds
		} else {
			write-host "`tNo instances to stop in region"
		}
	}
}
