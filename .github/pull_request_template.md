# Pull Request

## Changes Description

Brief description of what this PR accomplishes and why.

## Type of Change

- [ ] New role or feature
- [ ] Bug fix
- [ ] Documentation update
- [ ] Configuration change
- [ ] Refactoring
- [ ] Performance improvement

## Related Issues

Closes # (issue number)

## Testing Checklist

- [ ] **Syntax check passed**: `ansible-playbook playbooks/site.yml --syntax-check`
- [ ] **Validation script passed**: `./scripts/validate-setup.sh`
- [ ] **Tested in check mode**: `ansible-playbook playbooks/site.yml --check --ask-vault-pass`
- [ ] **Tested on actual target host** (if applicable)
- [ ] **Idempotency verified**: Running playbook twice shows no changes on second run
- [ ] **No vault.yml committed**: Only vault.yml.example should be in the repository

## Code Review Checklist

- [ ] Follows existing role patterns and structure
- [ ] Error handling implemented appropriately
- [ ] Uses `recreate: false` for container tasks (idempotency)
- [ ] Vault variables used for all secrets
- [ ] Appropriate Ansible tags added
- [ ] Comments added for complex logic
- [ ] Variable names are clear and descriptive

## Architecture Impact

Does this PR introduce any of the following? (Check all that apply)

- [ ] New API endpoints or changes to existing APIs
- [ ] Database schema changes
- [ ] New dependencies or packages
- [ ] Configuration file changes
- [ ] Breaking changes (requires manual intervention on upgrade)

If yes, please describe:

## Documentation

- [ ] README.md updated (if needed)
- [ ] CLAUDE.md updated (if architecture changed)
- [ ] CONTRIBUTING.md updated (if workflow changed)
- [ ] Inline comments added for complex logic
- [ ] Variable defaults documented in `defaults/main.yml`

## Deployment Notes

Any special instructions for deploying this change?

- Migration steps required:
- Configuration changes needed:
- Post-deployment verification:

## Screenshots (if applicable)

Add screenshots or terminal output to help explain your changes.

## Additional Context

Add any other context about the pull request here.

---

**Reviewer Notes:**

Please review with focus on:
- Security implications (vault usage, credentials, permissions)
- Performance considerations (query efficiency, resource usage)
- Idempotency (running playbook multiple times)
- Error handling and edge cases
