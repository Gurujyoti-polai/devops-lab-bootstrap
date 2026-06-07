variable "phase_name" {
  description = "Phase name — used for tagging all resources"
  type        = string
  default     = "phase-0"
}

variable "extra_ports" {
  description = "Extra inbound ports to open on the EC2 security group"
  type        = list(number)
  default     = []
}
