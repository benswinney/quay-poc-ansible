# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Ansible playbook for deploying Project Quay (open source) or Red Hat Quay (enterprise) container registry on RHEL 9 systems. This is a **Proof of Concept** deployment with local storage and single-node architecture.

## Project Structure

```
quay-poc-ansible/
├── ansible.cfg                    # Ansible configuration (SSH, privilege escalation)
├── playbooks/
│   └── site.yml                   # Main deployment orchestration playbook
├── inventory/
│   ├── hosts.yml                  # Target hosts configuration
│   └── group_vars/all/
│       ├── main.yml               # Primary configuration variables
│       ├── quay.yml               # Quay-specific variables and image mappings
│       └── vault.yml              # Encrypted secrets (passwords, certificates)
├── roles/                         # Ansible roles for each component
│   ├── common/                    # System preparation (packages, firewall, directories)
│   │   ├── tasks/main.yml         # Package installation, firewall rules, directory creation
│   │   └── defaults/main.yml      # Default variables for common role
│   ├── postgresql/                # PostgreSQL database deployment
│   │   ├── tasks/main.yml         # Database container deployment and initialization
│   │   └── defaults/main.yml      # PostgreSQL configuration (ports, versions)
│   ├── redis/                     # Redis cache deployment
│   │   ├── tasks/main.yml         # Redis container deployment
│   │   └── defaults/main.yml      # Redis configuration (port, password)
│   ├── quay/                      # Quay registry deployment + SSL
│   │   ├── tasks/
│   │   │   ├── main.yml           # Quay container deployment
│   │   │   └── ssl.yml            # SSL certificate generation/provisioning
│   │   ├── templates/
│   │   │   ├── config.yaml.j2     # Quay configuration template
│   │   │   └── openssl.cnf.j2     # OpenSSL configuration for cert generation
│   │   └── defaults/main.yml      # Quay configuration defaults
│   ├── clair/                     # Clair security scanner (optional)
│   │   ├── tasks/main.yml         # Clair container deployment
│   │   ├── templates/
│   │   │   └── clair-config.yaml.j2  # Clair configuration template
│   │   └── defaults/main.yml      # Clair configuration defaults
│   └── mirror/                    # Mirror worker (optional)
│       ├── tasks/main.yml         # Mirror worker container deployment
│       └── defaults/main.yml      # Mirror configuration defaults
└── scripts/
    └── validate-setup.sh          # Pre-deployment validation script
```

## Setup Instructions

### Prerequisites

**Control Node Requirements:**
- Ansible 2.14+ installed
- Python 3.9+ installed
- Required Ansible collections: `ansible.posix`, `containers.podman`

**Target Host Requirements:**
- RHEL 9 (or compatible: Rocky Linux 9, AlmaLinux 9)
- SSH access with sudo privileges
- Podman installed
- Firewall configured to allow ports: 80, 443, 5432, 6379, 6060, 6061
- Minimum hardware: 4GB RAM, 20GB disk space

### Initial Configuration

**1. Clone and Navigate**
```bash
git clone <repo-url>
cd quay-poc-ansible
```

**2. Run Validation Script**
```bash
./scripts/validate-setup.sh
```
This checks Ansible installation, required collections, inventory configuration, and vault setup.

**3. Install Ansible Collections**
```bash
ansible-galaxy collection install ansible.posix containers.podman
```

**4. Configure Inventory**

Edit `inventory/hosts.yml` and configure your target host:
```yaml
quay_servers:
  hosts:
    quay-server.example.com:
      ansible_host: 192.168.1.100
      ansible_user: root
```

**5. Configure Variables**

Edit `inventory/group_vars/all/main.yml`:
- Set `quay_hostname` to your server's FQDN or IP
- Choose distribution:
  - `quay_distribution: project` (open source, default)
  - `quay_distribution: redhat` (enterprise, requires credentials)
- Toggle optional components:
  - `quay_enable_clair: true` (vulnerability scanning)
  - `quay_enable_mirror: true` (repository mirroring)
- Configure SSL:
  - `quay_ssl_mode: selfsigned` (auto-generated certificates)
  - `quay_ssl_mode: provided` (use your own certificates)

**6. Create and Configure Vault**

```bash
# Copy template
cp inventory/group_vars/all/vault.yml.example inventory/group_vars/all/vault.yml

# Edit with actual credentials
ansible-vault edit inventory/group_vars/all/vault.yml
```

**Required vault variables:**
- `vault_postgresql_password` - PostgreSQL user password
- `vault_postgresql_admin_password` - PostgreSQL admin password
- `vault_redis_password` - Redis authentication password
- `vault_quay_secret_key` - UUID for Quay encryption (generate with `python3 -c "import uuid; print(uuid.uuid4())"`)
- `vault_quay_database_secret` - UUID for database encryption

**Optional vault variables (for Red Hat distribution):**
- `vault_registry_username` - Red Hat registry username
- `vault_registry_password` - Red Hat registry password

**Optional vault variables (for provided SSL mode):**
- `vault_ssl_cert` - SSL certificate content
- `vault_ssl_key` - SSL private key content
- `vault_ssl_ca` - CA bundle content (optional)

**7. Encrypt Vault**
```bash
ansible-vault encrypt inventory/group_vars/all/vault.yml
```

**8. Deploy**
```bash
ansible-playbook playbooks/site.yml --ask-vault-pass
```

The playbook will display a deployment summary upon completion with access URLs and next steps.

## Essential Commands

### Running the Playbook

```bash
# Full deployment
ansible-playbook playbooks/site.yml --ask-vault-pass

# Deploy specific components
ansible-playbook playbooks/site.yml --tags postgresql,redis,quay --ask-vault-pass
ansible-playbook playbooks/site.yml --skip-tags clair --ask-vault-pass

# Dry run (check mode)
ansible-playbook playbooks/site.yml --check --ask-vault-pass
```

### Ansible Collections

```bash
# Install required collections
ansible-galaxy collection install ansible.posix containers.podman
```

### Vault Management

```bash
# Create vault from template
cp inventory/group_vars/all/vault.yml.example inventory/group_vars/all/vault.yml

# Encrypt vault file
ansible-vault encrypt inventory/group_vars/all/vault.yml

# Edit encrypted vault
ansible-vault edit inventory/group_vars/all/vault.yml

# View encrypted vault
ansible-vault view inventory/group_vars/all/vault.yml

# Generate UUIDs for vault secrets
python3 -c "import uuid; print(uuid.uuid4())"
```

### Testing & Validation

**Pre-deployment Validation**

```bash
# Comprehensive validation script (checks Ansible, collections, inventory, vault)
./scripts/validate-setup.sh

# Manual pre-flight checks
ansible-playbook playbooks/site.yml --syntax-check          # Syntax validation
ansible-playbook playbooks/site.yml --list-hosts            # Verify target hosts
ansible-playbook playbooks/site.yml --list-tasks            # Preview all tasks
ansible-playbook playbooks/site.yml --list-tags             # Show available tags

# Test connectivity to target hosts
ansible quay_servers -m ping
```

**Post-deployment Verification**

```bash
# On target host - verify all containers are running
sudo podman ps

# Expected output should show:
# - postgresql-quay (Up)
# - redis-quay (Up)
# - quay (Up)
# - clair (Up, if enabled)
# - quay-mirror (Up, if enabled)

# Check Quay health endpoint
curl -k https://<quay_hostname>/health/instance
# Expected: {"status": "healthy"}

# Test database connectivity
sudo podman exec -it postgresql-quay psql -U quayuser -d quay -c "SELECT 1;"
# Expected: Output showing "1"

# Test Redis connectivity
sudo podman exec -it redis-quay redis-cli -a <vault_redis_password> PING
# Expected: PONG

# View container logs for errors
sudo podman logs quay | tail -50
sudo podman logs postgresql-quay | tail -20
sudo podman logs redis-quay | tail -20
sudo podman logs clair | tail -20  # if enabled
```

**Integration Testing**

```bash
# Test Quay web UI access
curl -k https://<quay_hostname>/
# Expected: HTML response with Quay UI

# Test container registry functionality
# 1. Login (use --tls-verify=false for self-signed certs)
podman login --tls-verify=false <quay_hostname>

# 2. Push test image
podman pull busybox:latest
podman tag busybox:latest <quay_hostname>/test/busybox:latest
podman push --tls-verify=false <quay_hostname>/test/busybox:latest

# 3. Pull test image
podman pull --tls-verify=false <quay_hostname>/test/busybox:latest

# Test Clair integration (if enabled)
# After pushing image, check Quay UI for vulnerability scan results
# Or query Clair API:
curl -k http://<quay_hostname>:6060/health
```

**Configuration Testing**

```bash
# Test configuration changes with dry run
ansible-playbook playbooks/site.yml --check --diff --ask-vault-pass

# Test specific component deployment
ansible-playbook playbooks/site.yml --tags postgresql --check --ask-vault-pass

# Verify generated configuration files on target
sudo podman exec quay cat /conf/stack/config.yaml
sudo podman exec clair cat /clair/config.yaml  # if enabled
```

**Performance & Load Testing**

```bash
# Monitor resource usage on target host
ssh <target-host> 'top -b -n 1 | head -20'
ssh <target-host> 'df -h /opt/quay'

# Check container resource usage
sudo podman stats --no-stream

# Test concurrent pushes (requires multiple terminals)
for i in {1..5}; do
  podman tag busybox:latest <quay_hostname>/test/busybox:v$i
  podman push --tls-verify=false <quay_hostname>/test/busybox:v$i &
done
```

### Troubleshooting on Target Host

```bash
# Check container status
sudo podman ps -a

# View logs
sudo podman logs quay
sudo podman logs postgresql-quay
sudo podman logs redis-quay
sudo podman logs clair

# Check Quay health
curl -k https://localhost/health/instance

# Verify database connection
sudo podman exec -it postgresql-quay psql -U quayuser -d quay -c "SELECT 1;"
```

## Development Workflow

### Testing Changes Locally

**1. Syntax Validation**
```bash
ansible-playbook playbooks/site.yml --syntax-check
```

**2. Dry Run (Check Mode)**
```bash
# See what would change without applying
ansible-playbook playbooks/site.yml --check --ask-vault-pass

# Include diff output to see exact changes
ansible-playbook playbooks/site.yml --check --diff --ask-vault-pass
```

**3. Test Specific Role**
```bash
# Deploy only PostgreSQL
ansible-playbook playbooks/site.yml --tags postgresql --ask-vault-pass

# Deploy database components only
ansible-playbook playbooks/site.yml --tags database,cache --ask-vault-pass

# Skip Clair deployment
ansible-playbook playbooks/site.yml --skip-tags clair --ask-vault-pass
```

**4. Validate Task Execution**
```bash
# List all tasks that will run
ansible-playbook playbooks/site.yml --list-tasks

# List all available tags
ansible-playbook playbooks/site.yml --list-tags

# List target hosts
ansible-playbook playbooks/site.yml --list-hosts
```

### Adding a New Role

When adding a new component (e.g., `monitoring`):

**1. Create Role Structure**
```bash
ansible-galaxy init roles/monitoring
```

**2. Define Role Variables**

Edit `roles/monitoring/defaults/main.yml`:
```yaml
---
# Monitoring role defaults
monitoring_enabled: true
monitoring_port: 9090
prometheus_version: "v2.45.0"
```

**3. Implement Role Tasks**

Edit `roles/monitoring/tasks/main.yml` following existing patterns:
- Check for existing containers with `podman_container_info`
- Use `containers.podman.podman_container` module
- Set `recreate: false` for idempotency
- Reference: `roles/redis/tasks/main.yml` or `roles/postgresql/tasks/main.yml`

**4. Add Role to Playbook**

Edit `playbooks/site.yml` (after mirror role at line ~144):
```yaml
- name: Deploy monitoring stack
  hosts: quay_servers
  become: true
  tags:
    - monitoring
    - observability
  roles:
    - role: monitoring
      when: quay_enable_monitoring | default(false) | bool
```

**5. Add Configuration Toggle**

Edit `inventory/group_vars/all/main.yml`:
```yaml
# Component Toggles
quay_enable_clair: true
quay_enable_mirror: true
quay_enable_monitoring: false  # Add this
```

**6. Test the New Role**
```bash
# Syntax check
ansible-playbook playbooks/site.yml --syntax-check

# Dry run
ansible-playbook playbooks/site.yml --tags monitoring --check --ask-vault-pass

# Deploy
ansible-playbook playbooks/site.yml --tags monitoring --ask-vault-pass
```

### Updating Container Versions

**Method 1: Update Version Variables** (Recommended)

Edit `inventory/group_vars/all/quay.yml`:
```yaml
# Container versions
quay_version: "3.12.0"        # Update to new version
clair_version: "4.7.4"        # Update to new version
postgresql_version: "15"       # Update major version if needed
redis_version: "7"
```

**Method 2: Override Distribution Image Mapping** (Advanced)

For custom registries or tags, edit the `quay_distribution_images` dictionary in `inventory/group_vars/all/quay.yml`:
```yaml
quay_distribution_images:
  project:
    quay: "quay.io/projectquay/quay:{{ quay_version }}"
    clair: "quay.io/projectquay/clair:{{ clair_version }}"
  custom:  # Add custom distribution
    quay: "myregistry.com/quay:custom-tag"
    clair: "myregistry.com/clair:custom-tag"
```

Then set `quay_distribution: custom` in `main.yml`.

**Deploy Updated Versions**
```bash
# Update specific component
ansible-playbook playbooks/site.yml --tags quay --ask-vault-pass

# Update all components
ansible-playbook playbooks/site.yml --ask-vault-pass
```

**Verify Version Update**
```bash
# On target host
sudo podman inspect quay | grep -i version
sudo podman logs quay | head -20  # Check startup logs for version
```

### Modifying Configuration

**For Variable Changes** (main.yml, quay.yml):
1. Edit configuration files
2. Run dry run: `ansible-playbook playbooks/site.yml --check --diff --ask-vault-pass`
3. Apply changes to affected components using tags

**For Vault Changes** (credentials, secrets):
```bash
# Edit vault
ansible-vault edit inventory/group_vars/all/vault.yml

# Apply changes (requires container recreation)
ansible-playbook playbooks/site.yml --ask-vault-pass
```

**For Template Changes** (config.yaml.j2, etc.):
1. Edit template files in `roles/*/templates/`
2. Deploy affected role: `ansible-playbook playbooks/site.yml --tags quay --ask-vault-pass`
3. Verify changes on target: `sudo podman exec quay cat /conf/stack/config.yaml`

## Architecture

### Deployment Flow

The playbook follows this execution order:
1. **common** - System preparation (packages, firewall, directories, registry auth)
2. **postgresql** - Database deployment for Quay and Clair
3. **redis** - Cache deployment
4. **quay** - Main registry container (includes SSL cert generation)
5. **clair** - Security scanner (conditional: `quay_enable_clair`)
6. **mirror** - Repository mirror worker (conditional: `quay_enable_mirror`)

### Component Tags

- `common`, `always` - System preparation (always runs)
- `postgresql`, `database` - PostgreSQL container
- `redis`, `cache` - Redis container
- `quay`, `registry` - Quay registry container
- `clair`, `security` - Clair vulnerability scanner
- `mirror`, `mirroring` - Mirror worker

### Key Configuration Variables

**Distribution Selection** (`inventory/group_vars/all/main.yml`):
- `quay_distribution`: `project` (default) or `redhat`
  - Automatically selects correct container images from `quay_distribution_images` mapping in `quay.yml`

**Component Toggles**:
- `quay_enable_clair`: `true`/`false` - Controls Clair deployment
- `quay_enable_mirror`: `true`/`false` - Controls Mirror worker deployment

**SSL Configuration**:
- `quay_ssl_mode`: `selfsigned` (default) or `provided`
  - `selfsigned`: Auto-generates certificates via `roles/quay/tasks/ssl.yml`
  - `provided`: Uses certificates from vault variables (`vault_ssl_cert`, `vault_ssl_key`)

**Container Image Mapping** (`inventory/group_vars/all/quay.yml`):
- Uses `quay_distribution_images` dictionary to map distribution → images
- Derived variables: `quay_image`, `clair_image`, `postgresql_image`, `redis_image`

### Vault Variables

All secrets stored in `inventory/group_vars/all/vault.yml` (encrypted):
- `vault_registry_username`, `vault_registry_password` - Registry credentials (required for Red Hat)
- `vault_postgresql_password`, `vault_postgresql_admin_password` - Database credentials
- `vault_redis_password` - Redis password
- `vault_quay_secret_key`, `vault_quay_database_secret` - UUIDs for Quay encryption
- `vault_ssl_cert`, `vault_ssl_key`, `vault_ssl_ca` - Optional provided certificates

### Directory Structure

```
/opt/quay/                    # quay_base_dir
├── config/                   # Quay config.yaml + SSL certs
├── storage/                  # Local storage (PoC only)
├── postgres/                 # PostgreSQL data
└── clair-config/             # Clair configuration
```

### Container Architecture

All services run as rootless Podman containers with `restart_policy: always`:
- **postgresql-quay**: Port 5432, databases: `quay`, `clair`
- **redis-quay**: Port 6379
- **quay**: Ports 80 (HTTP), 443 (HTTPS)
- **clair**: Ports 6060 (HTTP), 6061 (introspection)
- **quay-mirror**: No exposed ports

## Key File References

### Configuration Entry Points

**Primary Configuration** (`inventory/group_vars/all/main.yml`):
- Base directory: `main.yml:7` - `quay_base_dir: /opt/quay`
- Hostname: `main.yml:8` - `quay_hostname: quay-server.example.com`
- Distribution selection: `main.yml:13` - `quay_distribution: project|redhat`
- Component toggles: `main.yml:17-18` - `quay_enable_clair`, `quay_enable_mirror`
- SSL mode: `main.yml:23` - `quay_ssl_mode: selfsigned|provided`
- Superusers: `main.yml:38-39` - `quay_superusers` list

**Container Images** (`inventory/group_vars/all/quay.yml`):
- Distribution image mapping: `quay.yml:30-65` - `quay_distribution_images` dictionary
- Version variables: `quay.yml:10-15` - `quay_version`, `clair_version`, etc.
- Derived image variables: `quay.yml:67-70` - Auto-selected based on distribution

**Vault Secrets** (`inventory/group_vars/all/vault.yml`):
- All secrets encrypted with ansible-vault
- Database passwords, Redis password, Quay encryption keys
- Optional: Registry credentials (Red Hat), SSL certificates (provided mode)

**Inventory** (`inventory/hosts.yml`):
- Host definitions under `quay_servers` group
- SSH connection parameters: `ansible_host`, `ansible_user`

### Critical Playbook Sections

**Pre-flight Validation** (`playbooks/site.yml`):
- Vault file check: `site.yml:21-37`
- Inventory validation: `site.yml:39-53`
- Collection verification: `site.yml:55-76`

**Role Execution** (`playbooks/site.yml`):
- Common role: `site.yml:90-97` - Always runs (packages, firewall, directories)
- PostgreSQL role: `site.yml:99-106` - Database deployment
- Redis role: `site.yml:108-115` - Cache deployment
- Quay role: `site.yml:117-124` - Registry deployment
- Clair role: `site.yml:126-134` - Conditional on `quay_enable_clair`
- Mirror role: `site.yml:136-144` - Conditional on `quay_enable_mirror`

**Deployment Summary** (`playbooks/site.yml`):
- Success message: `site.yml:146-185` - Displays URLs, ports, next steps

### Role Implementation Files

**Common Role** (`roles/common/`):
- Main tasks: `roles/common/tasks/main.yml` - Package installation, firewall rules, directory creation, registry authentication
- Defaults: `roles/common/defaults/main.yml` - Package lists, directory paths

**PostgreSQL Role** (`roles/postgresql/`):
- Main tasks: `roles/postgresql/tasks/main.yml:1-60` - Container deployment, database initialization
- Container check: `roles/postgresql/tasks/main.yml:20-30` - Uses `podman_container_info`
- Database creation: `roles/postgresql/tasks/main.yml:40-55` - Creates `quay` and `clair` databases
- Defaults: `roles/postgresql/defaults/main.yml` - PostgreSQL version, port, image

**Redis Role** (`roles/redis/`):
- Main tasks: `roles/redis/tasks/main.yml` - Container deployment with password authentication
- Defaults: `roles/redis/defaults/main.yml` - Redis version, port, image

**Quay Role** (`roles/quay/`):
- Main tasks: `roles/quay/tasks/main.yml` - Config generation, container deployment
- SSL tasks: `roles/quay/tasks/ssl.yml:1-50` - Certificate generation/provisioning based on `quay_ssl_mode`
  - Self-signed generation: `ssl.yml:10-40` - OpenSSL certificate creation
  - Provided mode: `ssl.yml:42-50` - Copy from vault variables
- Config template: `roles/quay/templates/config.yaml.j2` - Quay configuration (database, Redis, SSL, storage)
- OpenSSL config: `roles/quay/templates/openssl.cnf.j2` - Certificate generation parameters
- Defaults: `roles/quay/defaults/main.yml` - Quay version, ports, SSL settings

**Clair Role** (`roles/clair/`):
- Main tasks: `roles/clair/tasks/main.yml` - Config generation, container deployment
- Config template: `roles/clair/templates/clair-config.yaml.j2` - Clair configuration (database, updaters)
- Defaults: `roles/clair/defaults/main.yml` - Clair version, ports

**Mirror Role** (`roles/mirror/`):
- Main tasks: `roles/mirror/tasks/main.yml` - Mirror worker container deployment
- Defaults: `roles/mirror/defaults/main.yml` - Mirror configuration

### Templates and Configuration

**Quay Configuration** (`roles/quay/templates/config.yaml.j2`):
- Database connection: `config.yaml.j2:5-10` - PostgreSQL connection string
- Redis connection: `config.yaml.j2:12-15` - Redis host/port/password
- SSL certificates: `config.yaml.j2:17-20` - Certificate paths in container
- Storage configuration: `config.yaml.j2:22-25` - LocalStorage backend
- Superusers: `config.yaml.j2:27-30` - Admin user list
- Clair integration: `config.yaml.j2:32-35` - Conditional on `quay_enable_clair`

**Clair Configuration** (`roles/clair/templates/clair-config.yaml.j2`):
- HTTP listen address: `clair-config.yaml.j2:3-5`
- Introspection address: `clair-config.yaml.j2:7-9`
- Database connection: `clair-config.yaml.j2:11-15`
- Updater configuration: `clair-config.yaml.j2:17-20`

### Validation Scripts

**Setup Validation** (`scripts/validate-setup.sh`):
- Ansible check: `validate-setup.sh:45-52` - Verifies Ansible installation
- Python check: `validate-setup.sh:54-61` - Verifies Python 3
- Collection checks: `validate-setup.sh:64-76` - Verifies ansible.posix, containers.podman
- Inventory check: `validate-setup.sh:79-87` - Validates hosts.yml configuration
- Vault check: `validate-setup.sh:90-104` - Validates vault.yml exists and encrypted
- Hostname check: `validate-setup.sh:107-117` - Warns about example hostnames
- Syntax check: `validate-setup.sh:120-130` - Validates playbook syntax

## Important Patterns

### Conditional Role Execution

Clair and Mirror roles use `when` conditions in playbook:
```yaml
roles:
  - role: clair
    when: quay_enable_clair | default(false) | bool
```

### Idempotency

- Container tasks check existence before creation (`podman_container_info`)
- Uses `recreate: false` to prevent unnecessary restarts
- SSL certificates only regenerated if missing

### SSL Certificate Handling

Self-signed mode (`roles/quay/tasks/ssl.yml`):
1. Generates private key
2. Creates CSR with hostname
3. Self-signs certificate (valid for `quay_ssl_cert_days`)

Provided mode:
- Reads from vault variables
- Copies to `{{ quay_config_dir }}/ssl.cert`, `ssl.key`

### Configuration Template

`roles/quay/templates/config.yaml.j2` generates Quay's `config.yaml`:
- Database connection strings (PostgreSQL)
- Redis connection
- SSL certificate paths
- Storage configuration (LocalStorage)
- Superuser list
- Clair integration (if enabled)

## Common Pitfalls

### Deployment Errors

**❌ "Vault file not found" Error**
- **Cause**: Vault file doesn't exist at expected path
- **Error**: `playbooks/site.yml:21-37` pre-flight validation fails
- **Fix**:
  ```bash
  cp inventory/group_vars/all/vault.yml.example inventory/group_vars/all/vault.yml
  ansible-vault edit inventory/group_vars/all/vault.yml
  # Fill in actual credentials
  ansible-vault encrypt inventory/group_vars/all/vault.yml
  ```

**❌ "No hosts configured in inventory" Error**
- **Cause**: `inventory/hosts.yml` has no uncommented hosts
- **Error**: `playbooks/site.yml:39-53` inventory validation fails
- **Fix**:
  ```bash
  # Edit inventory/hosts.yml and uncomment/configure at least one host
  vim inventory/hosts.yml
  ```

**❌ "Required collection not found" Error**
- **Cause**: Missing `ansible.posix` or `containers.podman` collections
- **Error**: `playbooks/site.yml:62-76` collection check fails
- **Fix**:
  ```bash
  ansible-galaxy collection install ansible.posix containers.podman
  ```

**❌ "Permission denied" SSH Error**
- **Cause**: SSH key not configured or user lacks sudo privileges
- **Error**: Initial connection to target host fails
- **Fix**:
  ```bash
  # Copy SSH key to target
  ssh-copy-id root@target-host

  # Or configure ansible_ssh_private_key_file in inventory
  # Ensure user has sudo/root access
  ```

**❌ "Image not found" Error (Red Hat Distribution)**
- **Cause**: Missing registry authentication for Red Hat images
- **Error**: Podman fails to pull from `registry.redhat.io`
- **Fix**: Set vault variables in `inventory/group_vars/all/vault.yml`:
  ```yaml
  vault_registry_username: "your-redhat-username"
  vault_registry_password: "your-redhat-password"
  ```
- **Reference**: `roles/common/tasks/main.yml` handles registry authentication

### Container Runtime Issues

**❌ "Port already in use" Error**
- **Cause**: Previous deployment not cleaned up or conflicting service
- **Error**: Podman container fails to start with port binding error
- **Fix on target host**:
  ```bash
  # Check running containers
  sudo podman ps -a

  # Remove conflicting containers
  sudo podman rm -f quay postgresql-quay redis-quay clair quay-mirror

  # Check for conflicting services
  sudo netstat -tulpn | grep -E ':(80|443|5432|6379|6060)'
  ```

**❌ Container Keeps Restarting**
- **Cause**: Configuration error, missing dependencies, or database connection failure
- **Diagnosis**:
  ```bash
  # Check container logs
  sudo podman logs quay
  sudo podman logs postgresql-quay

  # Check container status
  sudo podman ps -a
  sudo podman inspect quay | grep -A 10 State
  ```
- **Common causes**:
  - Database not ready: Wait 30 seconds after PostgreSQL deployment
  - Wrong vault password: Database connection strings use `vault_postgresql_password`
  - SSL certificate issues: Check `roles/quay/tasks/ssl.yml` execution

**❌ "Database connection refused" Error**
- **Cause**: PostgreSQL container not running or wrong credentials
- **Fix**:
  ```bash
  # Verify PostgreSQL container is running
  sudo podman ps | grep postgresql-quay

  # Test database connection
  sudo podman exec -it postgresql-quay psql -U quayuser -d quay -c "SELECT 1;"

  # Check PostgreSQL logs
  sudo podman logs postgresql-quay
  ```
- **Credential check**: Ensure `vault_postgresql_password` matches in vault and is correctly referenced

### SSL/TLS Issues

**⚠️ Self-signed Certificate Warnings (Expected Behavior)**
- **Cause**: Using `quay_ssl_mode: selfsigned` (default)
- **Manifestation**: Browser warnings, `podman login` requires `--tls-verify=false`
- **Workarounds**:
  ```bash
  # For Podman CLI
  podman login --tls-verify=false quay-server.example.com

  # For Docker CLI
  docker login --tls-verify=false quay-server.example.com
  ```
- **Production fix**: Switch to `quay_ssl_mode: provided` with valid certificates
- **Reference**: `roles/quay/tasks/ssl.yml:10-40` for self-signed generation

**❌ "SSL certificate verification failed" with Provided Certs**
- **Cause**: Certificate doesn't match hostname or is expired
- **Fix**:
  1. Verify certificate CN/SAN matches `quay_hostname`
  2. Check certificate validity: `openssl x509 -in ssl.cert -noout -dates`
  3. Ensure full certificate chain in `vault_ssl_cert`
  4. Verify private key matches certificate: `openssl x509 -in ssl.cert -noout -modulus | openssl md5; openssl rsa -in ssl.key -noout -modulus | openssl md5`

### Configuration Issues

**❌ Clair Not Scanning Images**
- **Cause**: Clair not enabled or database not initialized
- **Fix**:
  1. Verify: `quay_enable_clair: true` in `inventory/group_vars/all/main.yml:17`
  2. Check Clair container status: `sudo podman ps | grep clair`
  3. Check Clair logs: `sudo podman logs clair`
  4. Verify Clair database: `sudo podman exec -it postgresql-quay psql -U quayuser -d clair -c "SELECT 1;"`
- **Reference**: `playbooks/site.yml:126-134` for conditional execution

**❌ Mirror Worker Not Running**
- **Cause**: Mirror not enabled or configuration issue
- **Fix**:
  1. Verify: `quay_enable_mirror: true` in `inventory/group_vars/all/main.yml:18`
  2. Check mirror container: `sudo podman ps -a | grep quay-mirror`
  3. Check mirror logs: `sudo podman logs quay-mirror`
- **Reference**: `playbooks/site.yml:136-144` for conditional execution

**⚠️ Using Example Hostname**
- **Cause**: Forgot to change `quay_hostname` from default
- **Warning**: `scripts/validate-setup.sh:107-117` checks for example hostnames
- **Fix**: Edit `inventory/group_vars/all/main.yml:8` and set actual FQDN or IP

### Idempotency Issues

**⚠️ Containers Recreated on Every Run**
- **Cause**: Task not properly checking existing containers or `recreate: true` set
- **Expected**: All roles use `recreate: false` for idempotency
- **Diagnosis**: Check task uses `podman_container_info` before creation
- **Reference**: `roles/postgresql/tasks/main.yml:20-30` for pattern

**⚠️ SSL Certificates Regenerated**
- **Cause**: Missing certificate files or file check condition incorrect
- **Expected**: `roles/quay/tasks/ssl.yml` only generates if files missing
- **Fix**: Check `/opt/quay/config/ssl.cert` and `ssl.key` exist on target

### Vault Management

**❌ "Decryption failed" Error**
- **Cause**: Wrong vault password provided
- **Fix**: Ensure you're using the same password that was used to encrypt the vault
- **Reset vault** (if password lost):
  ```bash
  ansible-vault decrypt inventory/group_vars/all/vault.yml --ask-vault-pass
  # Enter old password

  ansible-vault encrypt inventory/group_vars/all/vault.yml
  # Enter new password
  ```

**❌ "Vault is not encrypted" Warning**
- **Cause**: Vault file contains sensitive data but isn't encrypted
- **Security risk**: Credentials stored in plain text
- **Fix**:
  ```bash
  ansible-vault encrypt inventory/group_vars/all/vault.yml
  ```
- **Reference**: `scripts/validate-setup.sh:99-103` checks encryption status

## Limitations & PoC Scope

- **Not production-ready**: Uses local storage, no HA, single node
- **Self-signed certs**: Default SSL mode requires `--tls-verify=false` for CLI
- **No backup/restore**: Manual backup required for `/opt/quay`
- **No monitoring**: No Prometheus/Grafana included

## Modifying the Playbook

### Adding a New Role

1. Create role structure: `ansible-galaxy init roles/new_role`
2. Add to `playbooks/site.yml` with appropriate tags
3. Define defaults in `roles/new_role/defaults/main.yml`
4. Add conditional execution if optional: `when: quay_enable_new_role | bool`

### Changing Container Images

Edit `inventory/group_vars/all/quay.yml`:
- Update version variables: `quay_version`, `clair_version`, etc.
- Or modify `quay_distribution_images` dictionary for custom registries

### Custom SSL Certificates

1. Set `quay_ssl_mode: provided` in `main.yml`
2. Add certificate content to vault:
   ```bash
   ansible-vault edit inventory/group_vars/all/vault.yml
   ```
3. Reference vault vars in `main.yml`:
   ```yaml
   quay_ssl_cert_content: "{{ vault_ssl_cert }}"
   quay_ssl_key_content: "{{ vault_ssl_key }}"
   ```
