# Tailscale Subnet Router — Azure + Terraform

A fully automated IaC deployment of a Tailscale subnet router on Microsoft Azure. Two Ubuntu VMs in an Azure VNet — one running Tailscale as the subnet router, one running nginx with no public IP. A single terraform apply deploys all 14 resources. No manual configuration beyond route approval.

## Architecture

- VNet: 10.0.0.0/16
- subnet-public (10.0.1.0/24): vm-subnet-router — Tailscale installed, public IP, ip_forwarding enabled
- subnet-private (10.0.2.0/24): vm-backend — nginx only, no public IP, no Tailscale client
- Traffic path: MacBook to Tailnet to vm-subnet-router to nginx on vm-backend
- Proof: curl http://10.0.2.4 returns HTTP 200 from a VM with no public IP

## Quick Start

    git clone https://github.com/alexbelsky99-ui/tailscale-subnet-router.git
    cd tailscale-subnet-router/azure/terraform
    cp terraform.tfvars.example terraform.tfvars
    # fill in tailscale_api_key, tailscale_tailnet, admin_ssh_public_key
    terraform init
    terraform apply -auto-approve

Takes 3-5 minutes. Approve the advertised route at https://login.tailscale.com/admin/machines then run:

    tailscale up --accept-routes
    curl http://10.0.2.4

## Design Decisions

**Azure over local VMs** — Production-grade network isolation. Same topology as a real enterprise deployment.

**ip_forwarding_enabled at two levels** — Azure requires it on the NIC resource in Terraform AND net.ipv4.ip_forward=1 via sysctl in cloud-init. Missing either causes silent traffic drop.

**cloud-init over post-deployment scripts** — Tailscale joins the Tailnet at first boot before terraform apply completes. No SSH needed, fully reproducible.

## AI Disclosure

Built with assistance from Claude (Anthropic) for scaffolding, debugging, and documentation. All code reviewed and validated through live deployment. Architecture decisions and tradeoff reasoning are my own.
