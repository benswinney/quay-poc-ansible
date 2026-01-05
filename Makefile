.PHONY: help deploy validate start stop restart status health logs clean

# Default target
.DEFAULT_GOAL := help

# Variables
PLAYBOOK := playbooks/site.yml
INVENTORY := inventory/hosts.yml
VALIDATE_SCRIPT := scripts/validate-setup.sh
VAULT_PASSWORD_FILE ?=
ANSIBLE_VAULT_OPTS := --ask-vault-pass
ANSIBLE_BECOME_OPTS := --ask-become-pass

# Container service names
POSTGRESQL_SERVICE := container-postgresql-quay.service
REDIS_SERVICE := container-redis-quay.service
QUAY_SERVICE := container-quay.service
CLAIR_SERVICE := container-clair.service
MIRROR_SERVICE := container-quay-mirror.service

# Core services (always deployed)
CORE_SERVICES := $(POSTGRESQL_SERVICE) $(REDIS_SERVICE) $(QUAY_SERVICE)

# Optional services (check if enabled)
OPTIONAL_SERVICES := $(CLAIR_SERVICE) $(MIRROR_SERVICE)

# Ansible ad-hoc command setup
SSH_HOST ?= $(shell grep -A 5 'quay_servers:' $(INVENTORY) | grep 'ansible_host:' | head -1 | awk '{print $$2}')
SSH_USER ?= $(shell grep -A 5 'quay_servers:' $(INVENTORY) | grep 'ansible_user:' | head -1 | awk '{print $$2}')

# For commands that need vault access (start/stop services)
ANSIBLE_CMD := ansible quay_servers -i $(INVENTORY) --become
ANSIBLE_CMD_SHELL := $(ANSIBLE_CMD) -m shell -a

# For monitoring commands that don't need vault (status, logs, health)
# Uses direct host connection to bypass group_vars loading
ANSIBLE_MONITOR_CMD := ansible all -i '$(SSH_HOST),' -u $(SSH_USER) --become
ANSIBLE_MONITOR_SHELL := $(ANSIBLE_MONITOR_CMD) -m shell -a

##@ General

help: ## Display this help message
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

##@ Deployment

validate: ## Run pre-deployment validation checks
	@echo "Running validation checks..."
	@bash $(VALIDATE_SCRIPT)

deploy: validate ## Deploy Quay POC environment (runs validation first)
	@echo "Starting deployment..."
	@echo "This will prompt for vault password and sudo password..."
	@ansible-playbook $(PLAYBOOK) $(ANSIBLE_VAULT_OPTS) $(ANSIBLE_BECOME_OPTS)
	@echo ""
	@echo "✓ Deployment complete!"
	@echo "Run 'make status' to check container status"

deploy-check: validate ## Dry run deployment (check mode, no changes)
	@echo "Running deployment in check mode (no changes will be made)..."
	@ansible-playbook $(PLAYBOOK) --check --diff $(ANSIBLE_VAULT_OPTS) $(ANSIBLE_BECOME_OPTS)

deploy-tags: validate ## Deploy specific components (usage: make deploy-tags TAGS=postgresql,redis)
	@if [ -z "$(TAGS)" ]; then \
		echo "Error: TAGS variable not set"; \
		echo "Usage: make deploy-tags TAGS=postgresql,redis,quay"; \
		exit 1; \
	fi
	@echo "Deploying components: $(TAGS)..."
	@ansible-playbook $(PLAYBOOK) --tags $(TAGS) $(ANSIBLE_VAULT_OPTS) $(ANSIBLE_BECOME_OPTS)

##@ Service Management (Remote)

start: ## Start all Quay services on target host
	@echo "Starting all Quay services on $(SSH_HOST)..."
	@$(ANSIBLE_CMD_SHELL) "systemctl start $(CORE_SERVICES)"
	@echo "Checking for optional services..."
	@$(ANSIBLE_CMD_SHELL) "systemctl list-unit-files | grep -q $(CLAIR_SERVICE) && systemctl start $(CLAIR_SERVICE) || true"
	@$(ANSIBLE_CMD_SHELL) "systemctl list-unit-files | grep -q $(MIRROR_SERVICE) && systemctl start $(MIRROR_SERVICE) || true"
	@echo "✓ Services started"
	@sleep 5
	@$(MAKE) status

stop: ## Stop all Quay services on target host
	@echo "Stopping all Quay services on $(SSH_HOST)..."
	@$(ANSIBLE_CMD_SHELL) "systemctl list-unit-files | grep -q $(MIRROR_SERVICE) && systemctl stop $(MIRROR_SERVICE) || true"
	@$(ANSIBLE_CMD_SHELL) "systemctl list-unit-files | grep -q $(CLAIR_SERVICE) && systemctl stop $(CLAIR_SERVICE) || true"
	@$(ANSIBLE_CMD_SHELL) "systemctl stop $(CORE_SERVICES)"
	@echo "✓ Services stopped"

restart: stop start ## Restart all Quay services on target host

status: ## Check status of all Quay services on target host
	@echo "Checking service status on $(SSH_HOST)..."
	@echo ""
	@echo "=== Systemd Services ==="
	@$(ANSIBLE_MONITOR_SHELL) "systemctl status $(CORE_SERVICES) --no-pager -l || true"
	@$(ANSIBLE_MONITOR_SHELL) "systemctl list-unit-files | grep -q $(CLAIR_SERVICE) && systemctl status $(CLAIR_SERVICE) --no-pager -l || true"
	@$(ANSIBLE_MONITOR_SHELL) "systemctl list-unit-files | grep -q $(MIRROR_SERVICE) && systemctl status $(MIRROR_SERVICE) --no-pager -l || true"
	@echo ""
	@echo "=== Container Status ==="
	@$(ANSIBLE_MONITOR_SHELL) "podman ps -a --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'"

health: ## Check health of all containers on target host
	@echo "Checking container health on $(SSH_HOST)..."
	@echo ""
	@echo "=== PostgreSQL Health ==="
	@$(ANSIBLE_MONITOR_SHELL) "podman healthcheck run postgresql-quay && echo '✓ Healthy' || echo '✗ Unhealthy'"
	@echo ""
	@echo "=== Redis Health ==="
	@$(ANSIBLE_MONITOR_SHELL) "podman healthcheck run redis-quay && echo '✓ Healthy' || echo '✗ Unhealthy'"
	@echo ""
	@echo "=== Quay Health ==="
	@$(ANSIBLE_MONITOR_SHELL) "podman healthcheck run quay && echo '✓ Healthy' || echo '✗ Unhealthy'"
	@echo ""
	@echo "=== Quay Health Endpoint ==="
	@$(ANSIBLE_MONITOR_SHELL) "curl -sk https://localhost/health/instance | jq . || echo '✗ Endpoint unavailable'"
	@echo ""
	@$(ANSIBLE_MONITOR_SHELL) "systemctl list-unit-files | grep -q $(CLAIR_SERVICE) && echo '=== Clair Health ===' && podman healthcheck run clair && echo '✓ Healthy' || echo '✗ Unhealthy' || true"

##@ Monitoring

logs: ## Show logs for all containers (usage: make logs CONTAINER=quay)
	@if [ -n "$(CONTAINER)" ]; then \
		echo "Showing logs for $(CONTAINER)..."; \
		$(ANSIBLE_MONITOR_SHELL) "podman logs -f $(CONTAINER)"; \
	else \
		echo "Showing recent logs for all containers..."; \
		echo ""; \
		echo "=== PostgreSQL Logs ==="; \
		$(ANSIBLE_MONITOR_SHELL) "podman logs --tail 20 postgresql-quay"; \
		echo ""; \
		echo "=== Redis Logs ==="; \
		$(ANSIBLE_MONITOR_SHELL) "podman logs --tail 20 redis-quay"; \
		echo ""; \
		echo "=== Quay Logs ==="; \
		$(ANSIBLE_MONITOR_SHELL) "podman logs --tail 50 quay"; \
		echo ""; \
		$(ANSIBLE_MONITOR_SHELL) "systemctl list-unit-files | grep -q $(CLAIR_SERVICE) && echo '=== Clair Logs ===' && podman logs --tail 20 clair || true"; \
		echo ""; \
		$(ANSIBLE_MONITOR_SHELL) "systemctl list-unit-files | grep -q $(MIRROR_SERVICE) && echo '=== Mirror Logs ===' && podman logs --tail 20 quay-mirror || true"; \
	fi

logs-follow: ## Follow logs for a specific container (usage: make logs-follow CONTAINER=quay)
	@if [ -z "$(CONTAINER)" ]; then \
		echo "Error: CONTAINER variable not set"; \
		echo "Usage: make logs-follow CONTAINER=quay"; \
		exit 1; \
	fi
	@echo "Following logs for $(CONTAINER)..."
	@$(ANSIBLE_MONITOR_SHELL) "podman logs -f $(CONTAINER)"

stats: ## Show container resource usage on target host
	@echo "Container resource usage on $(SSH_HOST)..."
	@$(ANSIBLE_MONITOR_SHELL) "podman stats --no-stream"

##@ Testing

test-registry: ## Test container registry functionality
	@echo "Testing Quay registry functionality..."
	@echo ""
	@echo "1. Testing Quay health endpoint..."
	@curl -sk https://$(SSH_HOST)/health/instance | jq . || echo "✗ Health check failed"
	@echo ""
	@echo "2. Testing registry login (requires credentials)..."
	@echo "   Run: podman login --tls-verify=false $(SSH_HOST)"
	@echo ""
	@echo "3. To test push/pull:"
	@echo "   podman pull busybox:latest"
	@echo "   podman tag busybox:latest $(SSH_HOST)/test/busybox:latest"
	@echo "   podman push --tls-verify=false $(SSH_HOST)/test/busybox:latest"
	@echo "   podman pull --tls-verify=false $(SSH_HOST)/test/busybox:latest"

test-restart: ## Test restart persistence (requires reboot access)
	@echo "Testing restart persistence..."
	@echo "This will reboot the target host: $(SSH_HOST)"
	@echo "Press Ctrl+C to cancel, or wait 10 seconds to continue..."
	@sleep 10
	@echo "Rebooting $(SSH_HOST)..."
	@$(ANSIBLE_MONITOR_SHELL) "systemctl reboot" || true
	@echo "Waiting 60 seconds for system to come back online..."
	@sleep 60
	@echo "Checking if services auto-started..."
	@$(MAKE) status

##@ Cleanup

clean-containers: ## Stop and remove all Quay containers (WARNING: destructive)
	@echo "WARNING: This will stop and remove all Quay containers"
	@echo "Press Ctrl+C to cancel, or wait 10 seconds to continue..."
	@sleep 10
	@echo "Stopping services..."
	@$(MAKE) stop
	@echo "Removing containers..."
	@$(ANSIBLE_MONITOR_SHELL) "podman rm -f postgresql-quay redis-quay quay clair quay-mirror 2>/dev/null || true"
	@echo "✓ Containers removed"

clean-data: ## Remove all Quay data (WARNING: extremely destructive)
	@echo "WARNING: This will delete ALL Quay data including databases and images"
	@echo "Press Ctrl+C to cancel, or wait 15 seconds to continue..."
	@sleep 15
	@$(MAKE) clean-containers
	@echo "Removing data directories..."
	@$(ANSIBLE_MONITOR_SHELL) "rm -rf /opt/quay/*"
	@echo "✓ Data removed"

clean-systemd: ## Remove systemd unit files for Quay containers
	@echo "Removing systemd unit files on $(SSH_HOST)..."
	@$(ANSIBLE_MONITOR_SHELL) "rm -f /etc/systemd/system/container-postgresql-quay.service"
	@$(ANSIBLE_MONITOR_SHELL) "rm -f /etc/systemd/system/container-redis-quay.service"
	@$(ANSIBLE_MONITOR_SHELL) "rm -f /etc/systemd/system/container-quay.service"
	@$(ANSIBLE_MONITOR_SHELL) "rm -f /etc/systemd/system/container-clair.service"
	@$(ANSIBLE_MONITOR_SHELL) "rm -f /etc/systemd/system/container-quay-mirror.service"
	@$(ANSIBLE_MONITOR_SHELL) "systemctl daemon-reload"
	@echo "✓ Systemd unit files removed"

##@ Vault Management

vault-edit: ## Edit encrypted vault file
	@ansible-vault edit inventory/group_vars/all/vault.yml

vault-view: ## View encrypted vault file
	@ansible-vault view inventory/group_vars/all/vault.yml

vault-encrypt: ## Encrypt vault file
	@ansible-vault encrypt inventory/group_vars/all/vault.yml

vault-decrypt: ## Decrypt vault file
	@ansible-vault decrypt inventory/group_vars/all/vault.yml

##@ Development

syntax-check: ## Check Ansible playbook syntax
	@echo "Checking playbook syntax..."
	@ansible-playbook $(PLAYBOOK) --syntax-check
	@echo "✓ Syntax check passed"

lint: ## Lint Ansible playbook with ansible-lint (if available)
	@if command -v ansible-lint >/dev/null 2>&1; then \
		echo "Running ansible-lint..."; \
		ansible-lint $(PLAYBOOK); \
	else \
		echo "ansible-lint not installed, skipping..."; \
		echo "Install with: pip install ansible-lint"; \
	fi

list-tasks: ## List all tasks in the playbook
	@ansible-playbook $(PLAYBOOK) --list-tasks

list-tags: ## List all available tags
	@ansible-playbook $(PLAYBOOK) --list-tags

list-hosts: ## List target hosts
	@ansible-playbook $(PLAYBOOK) --list-hosts

##@ Information

info: ## Display deployment information
	@echo "Quay POC Ansible Deployment"
	@echo "============================"
	@echo ""
	@echo "Playbook:    $(PLAYBOOK)"
	@echo "Inventory:   $(INVENTORY)"
	@echo "Target Host: $(SSH_USER)@$(SSH_HOST)"
	@echo ""
	@echo "Services:"
	@echo "  - PostgreSQL: $(POSTGRESQL_SERVICE)"
	@echo "  - Redis:      $(REDIS_SERVICE)"
	@echo "  - Quay:       $(QUAY_SERVICE)"
	@echo "  - Clair:      $(CLAIR_SERVICE) (optional)"
	@echo "  - Mirror:     $(MIRROR_SERVICE) (optional)"
	@echo ""
	@echo "Run 'make help' to see all available commands"

version: ## Show Ansible version
	@ansible --version
