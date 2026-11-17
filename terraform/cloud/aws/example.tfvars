aws_region           = "eu-central-1"
aws_profile          = "personal-infra"
instance_type        = "t3a.medium"
admin_cidrs          = ["198.51.100.10/32"]    # Replace with your current public IPv4 address.
ssh_public_key_path  = "~/.ssh/id_ed25519.pub" # Create a key pair first if this file does not exist.
ssh_private_key_path = "~/.ssh/id_ed25519"     # Keep the private key local and out of Git.
