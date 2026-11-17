# Repository instructions

- AWS is the selected cloud provider, with learning AWS as an explicit goal. Keep K3s and shared cluster configuration provider-independent. The existing OVH configuration is historical and must not be used to order another VPS. AWS provisioning awaits the reviewed AWS design and account authentication.
- Own the personal platform here: K3s, shared HTTPS, DNS record plans, and cluster backups. Keep application deployments in their own repositories.
- Use `uv` for Python dependencies, environments, lockfiles, and Python tooling.
- Never commit credentials, kubeconfigs, private keys, inventory containing real hosts, Terraform state, or backup passwords. Terraform must not receive runtime secret values.
- Keep versions pinned. Validate Terraform, Helm templates, Ansible syntax, shell scripts, Ruff, and ty before delivery; run meaningful local tests where possible.
- Do not provision cloud resources, change live DNS, or run the bootstrap playbook against a remote host unless explicitly requested.
