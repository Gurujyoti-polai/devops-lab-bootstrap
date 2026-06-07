# Provider config — tells OpenTofu which AWS region to use
provider "aws" {
  region = "ap-south-1"
}

# Required providers block — pins the AWS provider version
terraform {
  required_providers {
    aws = {
      source  = "registry.opentofu.org/hashicorp/aws"
      version = "~> 5.0"
    }
    http = {
      source  = "registry.opentofu.org/hashicorp/http"
      version = "~> 3.0"
    }
  }
  required_version = ">= 1.6.0"
}

# Call the lab module — this is what each phase will customise
module "lab" {
  source      = "./modules/lab"
  phase_name  = var.phase_name
  extra_ports = var.extra_ports
}
