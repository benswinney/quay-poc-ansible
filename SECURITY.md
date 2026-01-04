# Security Policy

## Reporting a Vulnerability

**DO NOT** open a public issue for security vulnerabilities.

Instead, please email: **benswinney@users.noreply.github.com**

Include the following information:
- Description of the vulnerability
- Steps to reproduce the issue
- Potential impact and severity
- Suggested fix (if any)
- Your contact information

We will respond within 48 hours and work with you to understand and address the issue.

## Security Best Practices

### Ansible Vault Files

This project uses Ansible Vault to protect sensitive credentials. Follow these guidelines:

1. **Always encrypt vault files**:
   ```bash
   ansible-vault encrypt inventory/group_vars/all/vault.yml
   ```

2. **Use strong vault passwords**:
   - Minimum 16 characters
   - Mix of uppercase, lowercase, numbers, and symbols
   - Store vault password securely (password manager, not in repo)

3. **Never commit unencrypted vault files**:
   - The `.gitignore` file excludes `**/vault.yml`
   - Only `vault.yml.example` should be committed
   - CI validation checks for accidental vault commits

4. **Rotate credentials regularly**:
   - Database passwords
   - Redis passwords
   - Quay secret keys
   - Registry credentials (for Red Hat distribution)

### SSL/TLS Certificates

**Self-Signed Mode** (default, `quay_ssl_mode: selfsigned`):
- Suitable for proof-of-concept and testing only
- Not recommended for production use
- Browsers and clients will show security warnings

**Provided Mode** (`quay_ssl_mode: provided`):
- Use valid certificates from a trusted CA for production
- Ensure private keys are stored in vault variables
- Set appropriate file permissions (600 for private keys)

### Production Deployments

**IMPORTANT**: This playbook is designed for proof-of-concept environments. For production deployments:

1. **Storage**: Replace LocalStorage with external storage backends
   - S3-compatible object storage
   - Google Cloud Storage
   - Azure Blob Storage

2. **High Availability**: Implement multi-node deployment
   - Multiple Quay instances behind load balancer
   - PostgreSQL replication or managed database service
   - Redis clustering or managed cache service

3. **SSL Certificates**: Use valid certificates from trusted CA
   - Let's Encrypt for automated certificate management
   - Commercial CA certificates
   - Internal PKI infrastructure

4. **Database Security**:
   - Use strong passwords (32+ characters)
   - Enable SSL/TLS for database connections
   - Restrict database access to Quay hosts only
   - Regular database backups

5. **Network Security**:
   - Use firewall rules to restrict access
   - Implement network segmentation
   - Use VPN or private networks for admin access
   - Enable fail2ban or similar intrusion prevention

6. **Access Control**:
   - Enable LDAP/OIDC authentication
   - Implement role-based access control (RBAC)
   - Enable audit logging
   - Regular access reviews

7. **Monitoring and Logging**:
   - Centralized log collection
   - Security event monitoring
   - Intrusion detection systems
   - Regular security audits

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| Latest  | :white_check_mark: |
| < Latest| :x:                |

This is a proof-of-concept project. Only the latest version on the main branch is supported.

## Known Limitations

### Proof-of-Concept Scope

This playbook has the following limitations:

1. **Single-node deployment**: No high availability or redundancy
2. **Local storage**: Not suitable for production data
3. **Self-signed certificates**: Default SSL configuration not trusted by browsers
4. **No backup/restore**: Manual backup procedures required
5. **No monitoring**: No built-in Prometheus/Grafana integration
6. **Basic authentication**: Superuser accounts only, no LDAP/OIDC

### Security Considerations

1. **Vault Password Security**:
   - Never commit vault passwords to the repository
   - Use `--ask-vault-pass` or vault password files with restricted permissions
   - Consider using `ansible-vault` password files stored outside the repo

2. **Registry Credentials**:
   - Required for Red Hat Quay distribution
   - Store in vault variables only
   - Rotate credentials after initial deployment

3. **Database Passwords**:
   - Generated UUIDs recommended for Quay secret keys
   - Strong random passwords for PostgreSQL and Redis
   - Change default passwords immediately

4. **Container Security**:
   - Keep container images updated
   - Monitor for security vulnerabilities with Clair
   - Subscribe to security advisories for Quay, PostgreSQL, Redis

## Security Updates

To update container images to address security vulnerabilities:

```bash
# Update version variables in inventory/group_vars/all/quay.yml
# Then run the playbook to pull new images

ansible-playbook playbooks/site.yml --tags quay --ask-vault-pass --ask-become-pass
```

Monitor these sources for security updates:
- [Quay Security Advisories](https://access.redhat.com/security/security-updates/#/security-advisories)
- [PostgreSQL Security](https://www.postgresql.org/support/security/)
- [Redis Security](https://redis.io/topics/security)

## Compliance

This proof-of-concept deployment does not meet compliance requirements for:
- PCI DSS
- HIPAA
- SOC 2
- GDPR (without additional controls)

For compliance requirements, consult with security professionals and implement additional controls beyond this playbook's scope.

## Security Checklist

Before deploying to any environment:

- [ ] Vault files encrypted with strong password
- [ ] All default passwords changed
- [ ] Firewall rules configured correctly
- [ ] SSL certificates properly configured
- [ ] Network access restricted to authorized hosts
- [ ] Vault password stored securely (not in repository)
- [ ] Registry credentials rotated after deployment
- [ ] Database backups configured (manual process)
- [ ] Monitoring and logging configured (external)
- [ ] Security updates applied to host system

## Contact

For security concerns, contact: **benswinney@users.noreply.github.com**

For general questions, use the [GitHub issue tracker](https://github.com/benswinney/quay-poc-ansible/issues).
