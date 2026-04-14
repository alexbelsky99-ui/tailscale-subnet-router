# Tailscale Subnet Router — Local Demo (Multipass + Terraform)

A fully automated, Infrastructure-as-Code deployment of a Tailscale subnet router using local VMs. This project provisions two Ubuntu VMs via Multipass, installs Tailscale on a subnet router VM, and exposes a private nginx backend through the Tailnet — no cloud account required, no public IP on the backend, no manual configuration beyond route approval.

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│  Multipass Network  192.168.64.0/24                         │
│                                                              │
│  ┌─────────────────────────┐   ┌────────────────────────┐  │
│  │  vm-subnet-router        │   │  vm-backend             │  │
│  │  192.168.64.3            │   │  192.168.64.11          │  │
│  │                          │   │                         │  │
│  │  Tailscale installed     ├───►  nginx on :80           │  │
│  │  ip_forward = 1          │   │  No Tailscale           │  │
│  │  Advertises /24 to       │   │  No public IP           │  │
│  │  Tailnet                 │   │                         │  │
│  └──────────┬───────────────┘   └────────────────────────┘  │
└─────────────┼────────────────────────────────────────────────┘
              │ WireGuard tunnel
              │
       ┌──────▼──────────┐
       │  Tailscale       │
       │  Control Plane   │
       └──────┬───────────┘
              │ Tailnet
              │
       ┌──────▼──────────┐
       │  MacBook Pro     │
       │  Tailscale       │
       │  client          │
       └─────────────────┘

Traffic: curl http://192.168.64.11 → Tailnet → subnet router → nginx
```

The backend VM is only reachable by devices enrolled in the Tailnet via the subnet router. It has no public IP and no internet-facing ports.

---

## Validation Output

![Connectivity Check](./validation-screenshot.png)

All 4 checks pass end-to-end:
- Tailscale running locally
- Subnet route `192.168.64.0/24` accepted in Tailnet
- ICMP ping to backend via subnet router
- HTTP 200 from nginx on private VM

---

## Prerequisites

| Requirement | Notes |
|---|---|
| [Terraform ≥ 1.5](https://developer.hashicorp.com/terraform/install) | `brew install hashicorp/tap/terraform` |
| [Multipass](https://multipass.run) | `brew install --cask multipass` |
| [Tailscale account](https://login.tailscale.com/start) | Free tier works |
| Tailscale API key | [Generate here](https://login.tailscale.com/admin/settings/keys) |
| Tailscale installed locally | [Download](https://tailscale.com/download) |

---

## Quick Start

### 1. Clone and configure

```bash
git clone https://github.com/<your-username>/tailscale-subnet-router.git
cd tailscale-subnet-router/terraform
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:

```hcl
tailscale_api_key      = "tskey-api-..."
tailscale_tailnet      = "you@gmail.com"
multipass_network_cidr = "192.168.64.0/24"
```

### 2. Deploy

```bash
terraform init
terraform apply -auto-approve
```

Takes ~5 minutes. Terraform launches both VMs, installs Tailscale on the router, and installs nginx on the backend.

### 3. Get the backend IP

```bash
multipass info vm-backend | grep IPv4
```

### 4. Approve the advertised route (one-time)

Go to: `https://login.tailscale.com/admin/machines` → find `vm-subnet-router` → **Edit route settings** → toggle on `192.168.64.0/24` → Save.

### 5. Validate

```bash
# Make sure you're connected to your Tailnet
tailscale up

# Run the validation script
chmod +x scripts/validate.sh
./scripts/validate.sh <backend-ip>

# Or just curl directly
curl http://<backend-ip>
```

### 6. Tear down

```bash
terraform destroy -auto-approve
```

---

## Design Choices

### Local VMs with Multipass instead of cloud

Multipass was chosen to eliminate the need for a cloud account while still producing a real, working network topology that faithfully represents the subnet router pattern. The Multipass network (`192.168.64.0/24`) functions identically to a cloud private subnet — the backend VM is unreachable except via the Tailscale overlay. The assignment explicitly allows "local VM or homelab" and Multipass runs natively on macOS with no additional infrastructure cost.

### IaC: Terraform with null_resource + local-exec

The project uses Terraform's `null_resource` with `local-exec` provisioners rather than the `larstobi/multipass` provider directly. This decision was made during deployment when the Multipass Terraform provider hit initialization timeouts waiting for cloud-init to complete. The `null_resource` approach decouples VM launch from VM configuration — VMs are launched bare and fast, then configured in a separate Terraform resource using `multipass exec`. This is more reliable and gives full visibility into what each step does.

The [official Tailscale Terraform provider](https://registry.terraform.io/providers/tailscale/tailscale/latest) (`tailscale/tailscale`) manages the auth key programmatically, so the entire deployment — VM provisioning and Tailnet join — is a single `terraform apply`.

### Backend service: nginx

nginx was chosen as a simple, universally recognizable proof-of-connectivity target. The cloud-init script renders a page showing the VM's real hostname and private IP, making it immediately obvious that you've reached the correct private endpoint.

### Key design decision: IP forwarding

The subnet router requires `net.ipv4.ip_forward=1` set at the OS level via sysctl. This is what allows the VM to forward packets on behalf of Tailscale clients — without it, Tailscale will connect but subnet traffic will be silently dropped. In a cloud deployment (e.g. Azure), IP forwarding must also be enabled at the NIC level separately; on Multipass this is handled at the OS layer only.

---

## Validation

The validation tests the full path end-to-end:

1. **Tailscale status** — confirms local client is enrolled and running
2. **Route acceptance** — confirms `192.168.64.0/24` is visible and accepted in the Tailnet
3. **ICMP ping** — confirms Layer 3 reachability through the subnet router
4. **HTTP curl** — confirms nginx is serving traffic on the private VM

The key proof: the backend VM has no Tailscale client, no public IP, and is not directly reachable from the MacBook's local network. A successful `curl http://192.168.64.11` proves the full routing chain — MacBook → Tailnet → subnet router → private VM — is working.

---

## Reflection & AI Disclosure

This project was built with assistance from Claude (Anthropic). AI was used for:

- **Initial scaffolding** — Terraform structure, provider configuration, cloud-init templates
- **Debugging** — troubleshooting Multipass provider timeouts and routing conflicts during live deployment
- **README drafting** — structure and wording, with editing for accuracy

All code was reviewed and validated through a complete live deployment. The architecture decisions, debugging approach, and tradeoff reasoning are my own. I believe being transparent about AI tool usage is important — particularly for a Solutions Engineer role where helping customers adopt new technology effectively is the core job.

---

## Alternatives and Future Improvements

**Route auto-approval via ACL**
Rather than manually approving routes in the admin console, add an `autoApprovers` block to your tailnet ACL policy:

```json
{
  "autoApprovers": {
    "routes": {
      "192.168.64.0/24": ["tag:subnet-router"]
    }
  }
}
```

**Tailscale SSH**
Replace the SSH key setup with [Tailscale SSH](https://tailscale.com/kb/1193/tailscale-ssh) to eliminate key management entirely and remove the need for any open ports.

**Cloud deployment**
The same Terraform structure maps cleanly to Azure or AWS — swap `null_resource` + `multipass` CLI for `azurerm_linux_virtual_machine` resources. The Tailscale configuration is identical; only the VM provisioning layer changes. Azure additionally requires `enable_ip_forwarding = true` on the NIC resource.

**Exit node**
Extend this demo with a [Tailscale exit node](https://tailscale.com/kb/1103/exit-nodes) to route all internet traffic through the Multipass VM, or use [Funnel](https://tailscale.com/kb/1223/funnel) to expose the backend to the public internet without opening any ports.

---

## Tailnet

`alexbelsky99@gmail.com`

---

## Repository Structure

```
tailscale-subnet-router/
├── terraform/
│   ├── providers.tf                  # tailscale + null providers
│   ├── variables.tf                  # input variables with defaults
│   ├── main.tf                       # Tailscale key + VM launch + configuration
│   ├── outputs.tf                    # IPs and helper commands
│   ├── terraform.tfvars.example      # template — copy to terraform.tfvars
│   └── templates/
│       ├── subnet-router-init.yaml.tpl
│       └── backend-init.yaml
├── scripts/
│   └── validate.sh                   # end-to-end connectivity check
├── validation-screenshot.png         # proof of connectivity
├── .gitignore
└── README.md
```
