# What phase is using this module — used for tagging and naming
variable "phase_name" {
  description = "Name of the phase using this module e.g. phase-0"
  type        = string
  default     = "phase-0"
}

# VPC CIDR — default covers 65,534 usable IPs across all subnets
variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

# Extra ports to open on the EC2 security group beyond SSH
# e.g. [8080, 8443] for a web app phase
variable "extra_ports" {
  description = "Additional ports to open inbound on the EC2 security group"
  type        = list(number)
  default     = []
}

# Path to your public key — used to create the EC2 key pair
variable "public_key_path" {
  description = "Path to the SSH public key for EC2 access"
  type        = string
  default     = "~/.ssh/devops-lab.pub"
}
