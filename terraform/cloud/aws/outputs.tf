output "server_ipv4" {
  description = "Elastic IPv4 address for Ansible and manual DNS configuration."
  value       = aws_eip.platform.public_ip
}

output "ansible_inventory" {
  description = "Save as ansible/inventory.yml after applying and checking the SSH host fingerprint."
  value = yamlencode({
    all = { children = { platform = { hosts = { personal = {
      ansible_host                 = aws_eip.platform.public_ip
      ansible_user                 = "ubuntu"
      ansible_ssh_private_key_file = pathexpand(var.ssh_private_key_path)
    } } } } }
  })
}

output "ssh_command" {
  description = "SSH command for the initial Ubuntu host, using the supplied key pair."
  value       = "ssh -i ${pathexpand(var.ssh_private_key_path)} ubuntu@${aws_eip.platform.public_ip}"
}

output "aws_region" {
  value = var.aws_region
}

output "availability_zone" {
  value = local.az
}
