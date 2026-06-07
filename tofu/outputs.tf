output "instance_public_ip" {
  value = module.lab.instance_public_ip
}

output "ssh_command" {
  value = module.lab.ssh_command
}

output "vpc_id" {
  value = module.lab.vpc_id
}
