---
name: Bug Report
about: Report a bug or unexpected behavior
title: '[BUG] '
labels: bug
assignees: ''
---

## Bug Description

A clear and concise description of what the bug is.

## Expected Behavior

What you expected to happen.

## Actual Behavior

What actually happened.

## Steps to Reproduce

1. Configure inventory with...
2. Run playbook with...
3. Observe error...

## Environment

**Ansible Version:**
```bash
ansible --version
```

**Python Version:**
```bash
python3 --version
```

**Operating System:**
- Control node OS: (e.g., macOS 14.2, Ubuntu 22.04)
- Target host OS: (e.g., RHEL 9.3, Rocky Linux 9.2)

**Quay Distribution:**
- [ ] Project Quay (open source)
- [ ] Red Hat Quay (enterprise)

**Affected Roles:**
- [ ] common
- [ ] postgresql
- [ ] redis
- [ ] quay
- [ ] clair
- [ ] mirror

## Configuration

**Relevant variable configuration** (from `inventory/group_vars/all/main.yml`):
```yaml
# Paste relevant configuration here
# IMPORTANT: Remove any sensitive information
```

## Logs and Error Messages

**Error output:**
```
Paste error messages here
```

**Ansible verbose output** (if available):
```bash
# Run with -vvv for verbose output
ansible-playbook playbooks/site.yml -vvv --ask-vault-pass
```

## Additional Context

Add any other context about the problem here:
- Screenshots
- Log files
- Container status (`podman ps -a`)
- Playbook run with `--check` mode

## Possible Solution

If you have suggestions on how to fix the bug, please describe them here.

## Checklist

- [ ] I have searched existing issues to ensure this is not a duplicate
- [ ] I have included all relevant environment information
- [ ] I have removed sensitive information (passwords, hostnames, etc.)
- [ ] I have included error logs and output
