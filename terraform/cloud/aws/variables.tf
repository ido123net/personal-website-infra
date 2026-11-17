variable "aws_region" {
  type        = string
  description = "AWS region for the personal platform."
  default     = "eu-central-1"
}

variable "aws_profile" {
  type        = string
  description = "Named AWS CLI profile authenticated through IAM Identity Center."
  default     = "personal-infra"
}

variable "name" {
  type        = string
  description = "Name prefix used for AWS resources."
  default     = "personal-platform"
}

variable "instance_type" {
  type        = string
  description = "EC2 type; the initial cost estimate uses t3a.medium."
  default     = "t3a.medium"
}

variable "root_volume_size_gib" {
  type        = number
  description = "Encrypted gp3 root disk size."
  default     = 40
  validation {
    condition     = var.root_volume_size_gib >= 30
    error_message = "The K3s host needs at least a 30 GiB root disk."
  }
}

variable "admin_cidrs" {
  type        = set(string)
  description = "Narrow IPv4 CIDRs permitted to SSH to the host; use your current public IP with /32."
  validation {
    condition = length(var.admin_cidrs) > 0 && alltrue([
      for cidr in var.admin_cidrs : can(cidrnetmask(cidr)) && try(tonumber(split("/", cidr)[1]) >= 24, false)
    ])
    error_message = "Provide at least one IPv4 CIDR with a /24 or narrower range, preferably your address as x.x.x.x/32."
  }
}

variable "ssh_public_key_path" {
  type        = string
  description = "Path to the administrator's public SSH key. Only the public key is uploaded to AWS."
  validation {
    condition     = length(var.ssh_public_key_path) > 0
    error_message = "Provide the path to an existing SSH public key."
  }
}

variable "ssh_private_key_path" {
  type        = string
  description = "Path to the matching private SSH key for local SSH and Ansible access."
  validation {
    condition     = length(var.ssh_private_key_path) > 0
    error_message = "Provide the path to the private SSH key matching ssh_public_key_path."
  }
}

variable "vpc_cidr" {
  type        = string
  description = "IPv4 range for the dedicated personal platform VPC."
  default     = "10.20.0.0/16"
}

variable "subnet_cidr" {
  type        = string
  description = "Public subnet range within the dedicated VPC."
  default     = "10.20.1.0/24"
}

variable "tags" {
  type        = map(string)
  description = "Additional tags applied to all taggable resources."
  default     = {}
}
