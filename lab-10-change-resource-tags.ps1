$instances = aws ec2 describe-instances --filter "Name=tag:Project,Values=ERPSystem" "Name=tag:Environment,Values=development" --query 'Reservations[*].Instances[*].InstanceId' --output text

$instances = $instances.split("\n")

aws ec2 create-tags --resources $instances --tags 'Key=Version,Value=1.1'