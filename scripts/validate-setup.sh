#!/bin/bash
# Quay POC Ansible - Setup Validation Script
# ===========================================
# This script validates that all prerequisites are met before running the playbook

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "=========================================="
echo "Quay POC Ansible - Setup Validation"
echo "=========================================="
echo ""

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

ERRORS=0
WARNINGS=0

# Function to print error
error() {
    echo -e "${RED}✗ ERROR:${NC} $1"
    ERRORS=$((ERRORS + 1))
}

# Function to print warning
warning() {
    echo -e "${YELLOW}⚠ WARNING:${NC} $1"
    WARNINGS=$((WARNINGS + 1))
}

# Function to print success
success() {
    echo -e "${GREEN}✓${NC} $1"
}

echo "Checking prerequisites..."
echo ""

# Check 1: Ansible installed
echo -n "Checking Ansible installation... "
if command -v ansible-playbook &> /dev/null; then
    ANSIBLE_VERSION=$(ansible-playbook --version | head -n1 | awk '{print $2}')
    success "Ansible $ANSIBLE_VERSION installed"
else
    error "Ansible not found. Please install Ansible 2.14+"
fi

# Check 2: Python 3 installed
echo -n "Checking Python installation... "
if command -v python3 &> /dev/null; then
    PYTHON_VERSION=$(python3 --version | awk '{print $2}')
    success "Python $PYTHON_VERSION installed"
else
    error "Python 3 not found. Please install Python 3.9+"
fi

# Check 3: Required Ansible collections
echo -n "Checking ansible.posix collection... "
if ansible-galaxy collection list 2>/dev/null | grep -q "ansible.posix"; then
    success "ansible.posix collection installed"
else
    error "ansible.posix collection not found. Install with: ansible-galaxy collection install ansible.posix"
fi

echo -n "Checking containers.podman collection... "
if ansible-galaxy collection list 2>/dev/null | grep -q "containers.podman"; then
    success "containers.podman collection installed"
else
    error "containers.podman collection not found. Install with: ansible-galaxy collection install containers.podman"
fi

# Check 4: Inventory configuration
echo -n "Checking inventory configuration... "
INVENTORY_FILE="$PROJECT_ROOT/inventory/hosts.yml"
if [ ! -f "$INVENTORY_FILE" ]; then
    error "Inventory file not found: $INVENTORY_FILE"
elif ! grep -q "^        [^#]" "$INVENTORY_FILE"; then
    error "No hosts configured in inventory/hosts.yml. Please uncomment and configure at least one host."
else
    success "Inventory file configured"
fi

# Check 5: Vault file exists
echo -n "Checking vault file... "
VAULT_FILE="$PROJECT_ROOT/inventory/group_vars/all/vault.yml"
if [ ! -f "$VAULT_FILE" ]; then
    error "Vault file not found. Create it with: cp inventory/group_vars/all/vault.yml.example inventory/group_vars/all/vault.yml"
    echo "         Then edit with your credentials and encrypt with: ansible-vault encrypt inventory/group_vars/all/vault.yml"
else
    success "Vault file exists"
    
    # Check if vault is encrypted
    if head -n1 "$VAULT_FILE" | grep -q "^\$ANSIBLE_VAULT"; then
        success "Vault file is encrypted"
    else
        warning "Vault file is not encrypted. Encrypt with: ansible-vault encrypt inventory/group_vars/all/vault.yml"
    fi
fi

# Check 6: Hostname configuration
echo -n "Checking hostname configuration... "
MAIN_CONFIG="$PROJECT_ROOT/inventory/group_vars/all/main.yml"
if [ -f "$MAIN_CONFIG" ]; then
    if grep -q "quay_hostname: quay-server.example.com\|quay_hostname: quay.example.com" "$MAIN_CONFIG"; then
        warning "Using example hostname in main.yml. Please set your actual hostname."
    else
        success "Hostname configured"
    fi
else
    error "Main configuration file not found: $MAIN_CONFIG"
fi

# Check 7: Syntax check
echo -n "Checking playbook syntax... "
PLAYBOOK="$PROJECT_ROOT/playbooks/site.yml"
if [ -f "$PLAYBOOK" ]; then
    if ansible-playbook "$PLAYBOOK" --syntax-check &> /dev/null; then
        success "Playbook syntax is valid"
    else
        error "Playbook syntax check failed. Run: ansible-playbook playbooks/site.yml --syntax-check"
    fi
else
    error "Playbook not found: $PLAYBOOK"
fi

echo ""
echo "=========================================="
echo "Validation Summary"
echo "=========================================="

if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo -e "${GREEN}✓ All checks passed!${NC}"
    echo ""
    echo "You can now run the playbook with:"
    echo "  ansible-playbook playbooks/site.yml --ask-vault-pass --ask-become-pass"
    exit 0
elif [ $ERRORS -eq 0 ]; then
    echo -e "${YELLOW}⚠ Validation completed with $WARNINGS warning(s)${NC}"
    echo ""
    echo "You can proceed, but please review the warnings above."
    exit 0
else
    echo -e "${RED}✗ Validation failed with $ERRORS error(s) and $WARNINGS warning(s)${NC}"
    echo ""
    echo "Please fix the errors above before running the playbook."
    exit 1
fi

# Made with Bob
