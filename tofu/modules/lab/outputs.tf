output "instance_public_ip" {
  description = "Public IP of the lab EC2 instance"
  value       = aws_instance.lab.public_ip
}

output "instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.lab.id
}

output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.lab.id
}

output "public_subnet_id" {
  description = "Public subnet ID"
  value       = aws_subnet.public.id
}

output "private_subnet_id" {
  description = "Private subnet ID"
  value       = aws_subnet.private.id
}

output "key_pair_name" {
  description = "Name of the EC2 key pair"
  value       = aws_key_pair.lab.key_name
}

output "ssh_command" {
  description = "Ready-to-run SSH command"
  value       = "ssh -i ~/.ssh/devops-lab ec2-user@${aws_instance.lab.public_ip}"
}
