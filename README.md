# Quay PoC Ansible

[![Ansible Lint](https://github.com/benswinney/quay-poc-ansible/actions/workflows/ansible-lint.yml/badge.svg)](https://github.com/benswinney/quay-poc-ansible/actions/workflows/ansible-lint.yml)
[![Validate Structure](https://github.com/benswinney/quay-poc-ansible/actions/workflows/validate-structure.yml/badge.svg)](https://github.com/benswinney/quay-poc-ansible/actions/workflows/validate-structure.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Ansible](https://img.shields.io/badge/Ansible-2.14%2B-blue.svg)](https://www.ansible.com/)

Ansible playbook for deploying [Project Quay](https://www.projectquay.io/) or [Red Hat Quay](https://www.redhat.com/en/technologies/cloud-computing/quay) on RHEL 9 for Proof of Concept environments.

## Features

- **Modular Distribution Selection**: Switch between Project Quay (open source) or Red Hat Quay (enterprise) via a single variable
- **Component Toggles**: Enable/disable Clair vulnerability scanner and Mirror worker
- **SSL Flexibility**: Self-signed certificates (default) or bring your own
- **Secure Credentials**: All secrets stored in Ansible Vault encrypted files
- **Idempotent**: Safe to run multiple times

## Requirements

### Control Node
- Ansible 2.14+
- Python 3.9+
- `ansible.posix` collection
- `containers.podman` collection

### Target Node
- RHEL 9 (or compatible: Rocky Linux 9, AlmaLinux 9)
- 2+ vCPUs
- 4+ GB RAM
- 30+ GB disk space
- Network access to container registries

## Quick Start

### 1. Validate Prerequisites

Before starting, run the validation script to check your setup:

```bash
./scripts/validate-setup.sh
```

This script checks:
- Ansible and Python installation
- Required Ansible collections
- Inventory configuration
- Vault file existence
- Hostname configuration
- Playbook syntax

### 2. Install Ansible Collections

```bash
ansible-galaxy collection install ansible.posix containers.podman
```

### 4. Configure Inventory

Edit `inventory/hosts.yml` to add your target server:

```yaml
all:
  children:
    quay_servers:
      hosts:
        quay-server.example.com:
          ansible_host: 192.168.1.100
          ansible_user: root
```

### 5. Configure Vault Credentials

```bash
# Copy the example vault file
cp inventory/group_vars/all/vault.yml.example inventory/group_vars/all/vault.yml

# Edit with your credentials
vi inventory/group_vars/all/vault.yml

# Encrypt the vault file
ansible-vault encrypt inventory/group_vars/all/vault.yml
```

### 6. Configure Variables

Edit `inventory/group_vars/all/main.yml`:

```yaml
# Set your hostname (REQUIRED - do not use example.com)
quay_hostname: quay.mycompany.com

# Choose distribution: 'project' or 'redhat'
quay_distribution: project

# Enable/disable components
quay_enable_clair: true
quay_enable_mirror: true

# SSL mode: 'selfsigned' or 'provided'
quay_ssl_mode: selfsigned
```

**Important:** The playbook will validate that you've changed the hostname from the default example values.

### 7. Run the Playbook

```bash
ansible-playbook playbooks/site.yml --ask-vault-pass
```

## Configuration Options

### Distribution Selection

| Variable | Options | Description |
|----------|---------|-------------|
| `quay_distribution` | `project`, `redhat` | Select open source or enterprise edition |

### Component Toggles

| Variable | Default | Description |
|----------|---------|-------------|
| `quay_enable_clair` | `true` | Enable Clair vulnerability scanner |
| `quay_enable_mirror` | `true` | Enable repository mirroring |

### SSL/TLS Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `quay_ssl_mode` | `selfsigned` | `selfsigned` or `provided` |
| `quay_ssl_cert_days` | `365` | Validity for self-signed certs |
| `quay_ssl_cert_file` | - | Path to provided certificate |
| `quay_ssl_key_file` | - | Path to provided key |

### Version Pinning

Edit `inventory/group_vars/all/quay.yml`:

```yaml
quay_version: "3.12.0"
clair_version: "4.7.4"
postgresql_version: "13"
redis_version: "7"
```

## Vault Variables

The following variables should be defined in `inventory/group_vars/all/vault.yml`:

| Variable | Description |
|----------|-------------|
| `vault_registry_username` | Container registry username (for Red Hat) |
| `vault_registry_password` | Container registry password |
| `vault_postgresql_password` | PostgreSQL user password |
| `vault_postgresql_admin_password` | PostgreSQL admin password |
| `vault_redis_password` | Redis password |
| `vault_quay_secret_key` | Quay secret key (UUID) |
| `vault_quay_database_secret` | Quay database secret (UUID) |

Generate UUIDs with:
```bash
python3 -c "import uuid; print(uuid.uuid4())"
```

## Project Structure

```
quay-poc-ansible/
├── ansible.cfg
├── inventory/
│   ├── hosts.yml
│   └── group_vars/all/
│       ├── main.yml          # Main configuration
│       ├── quay.yml          # Version and image settings
│       └── vault.yml.example # Vault template
├── playbooks/
│   └── site.yml              # Main playbook
├── roles/
│   ├── common/               # System preparation
│   ├── postgresql/           # Database
│   ├── redis/                # Cache
│   ├── quay/                 # Registry
│   ├── clair/                # Vulnerability scanner
│   └── mirror/               # Mirror worker
└── README.md
```

## Usage Examples

### Deploy Everything

```bash
ansible-playbook playbooks/site.yml --ask-vault-pass
```

### Deploy Specific Components

```bash
# Only deploy database and cache
ansible-playbook playbooks/site.yml --tags postgresql,redis --ask-vault-pass

# Skip Clair
ansible-playbook playbooks/site.yml --skip-tags clair --ask-vault-pass
```

### Check Mode (Dry Run)

```bash
ansible-playbook playbooks/site.yml --check --ask-vault-pass
```

## Post-Deployment

### Access the Web Interface

Navigate to `https://<quay_hostname>` and create your first account.

### Login via CLI

```bash
# With self-signed certificate
podman login --tls-verify=false quay.example.com

# With valid certificate
podman login quay.example.com
```

### Push an Image

```bash
podman pull docker.io/library/busybox
podman tag docker.io/library/busybox quay.example.com/myorg/busybox:latest
podman push --tls-verify=false quay.example.com/myorg/busybox:latest
```

## Limitations

This is a **Proof of Concept** deployment:

- Uses local storage (not suitable for production)
- Single-node deployment (no HA)
- Self-signed certificates by default

For production deployments, refer to the official documentation:
- [Project Quay Documentation](https://docs.projectquay.io/)
- [Red Hat Quay Documentation](https://access.redhat.com/documentation/en-us/red_hat_quay)

## Troubleshooting

### Check Container Status

```bash
sudo podman ps -a
```

### View Container Logs

```bash
sudo podman logs quay
sudo podman logs postgresql-quay
sudo podman logs redis-quay
sudo podman logs clair
```

### Verify Database Connection

```bash
sudo podman exec -it postgresql-quay psql -U quayuser -d quay -c "SELECT 1;"
```

### Check Quay Health

```bash
curl -k https://localhost/health/instance
```

## License

MIT
