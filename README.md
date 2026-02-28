# Gaming Server - Minecraft Bedrock

Terraform and Ansible repository for provisioning a Minecraft Bedrock gaming server on vSphere.
Runs up to 4 concurrent world instances on a single VM using systemd template services.

## Prerequisites

- Terraform >= 1.9.8
- Ansible >= 2.14
- Python 3.11+
- Access to vSphere environment
- SSH key pair for Ansible authentication

## Repository Structure

```
core-gaming-vs-build/
├── ansible/
│   ├── inventory/
│   │   ├── ansible_inventory.py          # Dynamic inventory from Terraform output
│   │   ├── files/
│   │   │   └── bedrock-backup.gz         # World backup archive (restored on first deploy)
│   │   ├── group_vars/all/
│   │   │   └── minecraft.yml             # World instances, ports, gamemodes
│   │   └── ssh_keys/                     # SSH keys for Ansible (not committed)
│   └── playbooks/
│       ├── site_gaming.yml               # Main playbook (common + minecraft roles)
│       └── roles/
│           ├── common/                   # Base OS configuration
│           └── minecraft/                # Minecraft Bedrock install & management
│               ├── tasks/
│               │   ├── install.yml       # Download & install latest Bedrock binary
│               │   ├── worlds.yml        # Restore worlds from backup archive
│               │   ├── services.yml      # systemd service instances + UFW rules
│               │   └── maintenance.yml   # Backup & auto-update timers
│               └── templates/
│                   ├── server.properties.j2       # Per-world server config
│                   ├── minecraft@.service.j2      # systemd template service
│                   ├── minecraft-backup.sh.j2     # Daily backup script
│                   └── minecraft-update.sh.j2     # Auto-update script
├── modules/
│   └── compute/
│       └── vsphere-vm/                   # VM provisioning module
├── environments/
│   ├── local.tfvars                      # Local machine settings
│   └── production.tfvars                 # Gaming server VM settings
├── scripts/
│   ├── setup.sh                          # Environment setup
│   ├── deploy.sh                         # Full deploy (Terraform + Ansible)
│   └── destroy.sh                        # Tear down infrastructure
├── main.tf
├── variables.tf
├── outputs.tf
└── versions.tf
```

## Gaming Server VM

| Setting | Value |
|---|---|
| Name | Gaming-Server |
| IP | 10.10.40.20 |
| vCPU | 6 |
| RAM | 16 GB |
| Disk | 100 GB |
| Network | VLAN40-SERVERS |

## Minecraft Worlds

Four world instances run concurrently, each as a separate systemd service (`minecraft@<name>`):

| Instance | World | Port | Mode |
|---|---|---|---|
| `minecraft@marshlands-survival` | Marshlands_Survival | 19132 UDP | Survival |
| `minecraft@epic-survival` | Epic_World_Survival | 19133 UDP | Survival |
| `minecraft@marshlands` | Marshlands | 19134 UDP | Creative |
| `minecraft@epic-world` | Epic_World | 19135 UDP | Creative |

To add, remove, or reconfigure worlds edit `ansible/inventory/group_vars/all/minecraft.yml` and re-run Ansible.

## On-Server Layout

```
/opt/minecraft/
├── bin/                    # Shared Bedrock binary + runtime libraries
├── servers/
│   ├── marshlands-survival/
│   ├── epic-survival/
│   ├── marshlands/
│   └── epic-world/
├── backups/                # Daily + pre-update backup archives
├── scripts/
│   ├── minecraft-backup.sh
│   └── minecraft-update.sh
└── current_version         # Installed Bedrock version string
```

## Automated Maintenance

| Schedule | Action |
|---|---|
| 03:00 daily | Back up all worlds and configs to `/opt/minecraft/backups/` |
| 04:00 daily | Check minecraft.net for a new Bedrock version; if found: backup → stop → update → restart |

Backups are retained for 14 days. Logs: `/var/log/minecraft-backup.log`, `/var/log/minecraft-update.log`.

## Quick Start

### 1. Initial Setup

```bash
chmod +x scripts/setup.sh
./scripts/setup.sh
```

### 2. Configure SSH Keys

```bash
mkdir -p ./ansible/inventory/ssh_keys
cp /path/to/private_key ./ansible/inventory/ssh_keys/vsphere_ansible_key
cp /path/to/public_key  ./ansible/inventory/ssh_keys/vsphere_terraform_key.pub
chmod 600 ./ansible/inventory/ssh_keys/vsphere_ansible_key
chmod 700 ./ansible/inventory/ssh_keys
```

### 3. Deploy

```bash
chmod +x scripts/deploy.sh
./scripts/deploy.sh
```

The script will prompt for your vSphere password, provision the VM via Terraform, then run the Ansible playbook to install and configure everything.

## Manual Deployment

```bash
export TF_VAR_gbl_vsphere_password="your-password"

terraform init
terraform workspace new production
terraform apply \
  -var-file=environments/local.tfvars \
  -var-file=environments/production.tfvars

terraform output -json ansible_inventory > ./ansible/inventory/terraform.json

ansible-playbook -i ./ansible/inventory/ansible_inventory.py \
  ./ansible/playbooks/site_gaming.yml
```

## Managing Server Instances

```bash
# Status of all instances
systemctl status 'minecraft@*'

# Stop / start a specific world
systemctl stop  minecraft@marshlands-survival
systemctl start minecraft@marshlands-survival

# Live logs for a world
journalctl -u minecraft@epic-survival -f

# Trigger a manual backup
/opt/minecraft/scripts/minecraft-backup.sh manual

# Trigger a manual update check
/opt/minecraft/scripts/minecraft-update.sh
```

## Destroy Infrastructure

```bash
chmod +x scripts/destroy.sh
./scripts/destroy.sh
```

## Troubleshooting

### SSH Key Permissions

```bash
chmod 600 ./ansible/inventory/ssh_keys/vsphere_ansible_key
chmod 700 ./ansible/inventory/ssh_keys
```

### Debug Ansible Inventory

```bash
ANSIBLE_INVENTORY_DEBUG=true ansible-inventory \
  -i ./ansible/inventory/ansible_inventory.py --list
```

### Terraform State Issues

```bash
rm -rf .terraform* terraform*
terraform init
```

## Security Notes

- Never commit SSH keys or passwords to version control
- Use environment variables for sensitive data (`TF_VAR_gbl_vsphere_password`)
- Sensitive Ansible vars should be encrypted with `ansible-vault`
