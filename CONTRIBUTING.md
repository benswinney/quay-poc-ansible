# Contributing to Quay PoC Ansible

Thank you for your interest in contributing to this project! This document provides guidelines for contributing to the Quay PoC Ansible playbook.

## How to Contribute

### Reporting Issues

- Use the GitHub issue tracker to report bugs
- Include detailed information: Ansible version, Python version, OS, error messages
- Provide steps to reproduce the issue

### Submitting Changes

1. **Fork the repository**
2. **Create a feature branch** using the naming convention:
   - `feature/description` - New features or enhancements
   - `bugfix/description` - Bug fixes
   - `hotfix/description` - Urgent production fixes
   - `docs/description` - Documentation updates
3. **Make your changes**
4. **Test your changes**:
   - Run syntax check: `ansible-playbook playbooks/site.yml --syntax-check`
   - Run validation: `./scripts/validate-setup.sh`
   - Test in check mode: `ansible-playbook playbooks/site.yml --check --ask-vault-pass`
   - Verify idempotency (run twice, second run should show no changes)
5. **Commit your changes** using conventional commits format
6. **Push to your fork**
7. **Submit a pull request**

## Branch Naming Convention

Use descriptive branch names with the following prefixes:

- `feature/` - New features (e.g., `feature/add-monitoring-role`)
- `bugfix/` - Bug fixes (e.g., `bugfix/fix-ssl-generation`)
- `hotfix/` - Urgent fixes (e.g., `hotfix/security-patch`)
- `docs/` - Documentation (e.g., `docs/update-readme`)

## Commit Message Format

Follow the [Conventional Commits](https://www.conventionalcommits.org/) specification:

```
<type>[optional scope]: <description>

[optional body]

[optional footer]
```

### Types

- `feat` - New feature
- `fix` - Bug fix
- `docs` - Documentation changes
- `test` - Adding or updating tests
- `refactor` - Code refactoring
- `perf` - Performance improvements
- `chore` - Maintenance tasks

### Examples

```bash
feat(quay): add support for external storage backends
fix(postgresql): resolve database initialization timeout
docs: update SSL certificate configuration guide
test(common): add firewall rule validation tests
refactor(redis): simplify password configuration
```

### Scope

Use role names as scope when applicable:
- `common`, `postgresql`, `redis`, `quay`, `clair`, `mirror`

## Pull Request Guidelines

### Before Submitting

- [ ] Fill out the pull request template completely
- [ ] Ensure all CI checks pass
- [ ] Update documentation if needed (README.md, CLAUDE.md)
- [ ] Keep changes focused and atomic
- [ ] Squash commits if needed to maintain clean history

### PR Review Process

1. Automated checks must pass (ansible-lint, syntax validation)
2. At least one approval required
3. All conversations must be resolved
4. PRs will be merged using squash merge

### Testing Checklist

Before submitting your PR, ensure:

- [ ] **Syntax check passes**: `ansible-playbook playbooks/site.yml --syntax-check`
- [ ] **Validation script passes**: `./scripts/validate-setup.sh`
- [ ] **Check mode succeeds**: `ansible-playbook playbooks/site.yml --check`
- [ ] **Tested on actual target host** (if possible)
- [ ] **Idempotency verified**: Running playbook twice shows no changes on second run
- [ ] **No vault.yml committed**: Only vault.yml.example should be in the repo

### Code Review Checklist

Your code should follow these patterns:

- [ ] Follows existing role structure and patterns
- [ ] Uses appropriate error handling
- [ ] Sets `recreate: false` for container tasks (idempotency)
- [ ] Uses vault variables for sensitive data
- [ ] Adds appropriate Ansible tags
- [ ] Includes comments for complex logic
- [ ] Updates defaults/main.yml for new variables

## Development Workflow

### Local Testing

```bash
# 1. Syntax validation
ansible-playbook playbooks/site.yml --syntax-check

# 2. Dry run (see what would change)
ansible-playbook playbooks/site.yml --check --diff --ask-vault-pass

# 3. Test specific role
ansible-playbook playbooks/site.yml --tags postgresql --ask-vault-pass

# 4. List all tasks
ansible-playbook playbooks/site.yml --list-tasks

# 5. Validate project structure
./scripts/validate-setup.sh
```

### Adding a New Role

When adding a new component:

1. Create role structure: `ansible-galaxy init roles/role_name`
2. Define variables in `roles/role_name/defaults/main.yml`
3. Implement tasks following existing patterns (check for existing containers)
4. Add role to `playbooks/site.yml` with appropriate tags
5. Add configuration toggle in `inventory/group_vars/all/main.yml`
6. Update documentation (README.md, CLAUDE.md)
7. Test thoroughly

### Code Style

- Use 2 spaces for indentation (YAML)
- Follow existing naming conventions
- Keep lines under 120 characters
- Use meaningful variable names
- Add comments for complex logic

## Project-Specific Guidelines

### Ansible Best Practices

- Always check for existing resources before creating (idempotency)
- Use `containers.podman.podman_container` module for containers
- Set `recreate: false` to prevent unnecessary restarts
- Use vault variables for all secrets
- Add appropriate tags to tasks
- Follow the role pattern established in existing roles

### Vault Usage

- Never commit unencrypted `vault.yml` files
- Always use vault variables for passwords and secrets
- Keep `vault.yml.example` updated with placeholder values
- Test with `--ask-vault-pass` flag

### Container Management

- Check for existing containers using `podman_container_info`
- Use `restart_policy: always` for production containers
- Mount configurations as volumes
- Use descriptive container names

## Questions or Need Help?

- Review existing issues and pull requests
- Check the [README.md](README.md) for usage documentation
- Review [CLAUDE.md](CLAUDE.md) for development details
- Open an issue for questions or discussions

## Code of Conduct

This project follows a professional code of conduct. Be respectful, constructive, and collaborative.

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
