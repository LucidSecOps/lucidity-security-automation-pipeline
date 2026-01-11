# Contributing Guide

Thank you for your interest in contributing to the Security Automation Pipeline! This guide will help you get started.

## Ways to Contribute

### 1. Report Issues
- Bug reports
- Feature requests
- Documentation improvements
- Security vulnerabilities (see Security Policy below)

### 2. Code Contributions
- Bug fixes
- New integrations (firewalls, notification channels)
- Performance improvements
- Test coverage

### 3. Documentation
- Installation guides for different environments
- Tutorials and examples
- Translations

## Getting Started

### Fork and Clone

```bash
# Fork the repository on GitHub, then:
git clone https://github.com/YOUR_USERNAME/security-automation-pipeline.git
cd security-automation-pipeline
git remote add upstream https://github.com/LucidSecOps/lucidity-security-automation-pipeline.git
```

### Set Up Development Environment

1. Install required components (see INSTALLATION.md)
2. Configure with test/development credentials
3. Verify the pipeline works end-to-end

### Create a Branch

```bash
git checkout -b feature/your-feature-name
# or
git checkout -b fix/issue-description
```

## Contribution Guidelines

### Code Style

**Python:**
- Follow PEP 8
- Use type hints where appropriate
- Document functions with docstrings

**Groovy/Jenkins:**
- Use consistent indentation (4 spaces)
- Comment complex logic

**SQL:**
- Use uppercase for SQL keywords
- Prefix table names with schema

**JSON:**
- Use 2-space indentation
- Keep node IDs descriptive

### Commit Messages

Use conventional commit format:

```
type(scope): description

[optional body]

[optional footer]
```

Types:
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation
- `style`: Formatting
- `refactor`: Code restructuring
- `test`: Adding tests
- `chore`: Maintenance

Examples:
```
feat(firewall): add FortiGate integration
fix(n8n): handle null agent IP in PostgreSQL
docs(install): add Docker deployment guide
```

### Pull Request Process

1. **Update documentation** if your change affects usage
2. **Test your changes** end-to-end
3. **Update CHANGELOG.md** with your changes
4. **Create PR** with clear description
5. **Respond to feedback** from reviewers

### PR Description Template

```markdown
## Description
Brief description of changes

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Documentation update
- [ ] Performance improvement

## Testing Done
- [ ] Tested with Wazuh alerts
- [ ] Tested MISP enrichment
- [ ] Tested PostgreSQL logging
- [ ] Tested firewall blocking

## Checklist
- [ ] Code follows project style
- [ ] Self-reviewed code
- [ ] Commented complex code
- [ ] Updated documentation
- [ ] No sensitive data in commits
```

## Adding New Integrations

### New Firewall Type

1. Create example config in `configs/firewall/`
2. Add n8n nodes template in `configs/n8n/`
3. Document API requirements in `docs/`
4. Add to README firewall alternatives table

### New Notification Channel

1. Add n8n node configuration to workflow
2. Document credential requirements
3. Add example payload format

### New IOC Type

1. Update "Extract IOCs" code node
2. Add MISP attribute mapping
3. Test with sample alerts
4. Document in ARCHITECTURE.md

## Testing

### Manual Testing

```bash
# Run health check
./scripts/health-check.sh

# Send test alerts
./scripts/test-pipeline.sh http://your-n8n:5678/webhook/wazuh-alert

# Verify PostgreSQL
psql -c "SELECT COUNT(*) FROM security.wazuh_misp_alerts WHERE timestamp > NOW() - INTERVAL '1 hour';"
```

### What to Test

- [ ] Alert flow from Wazuh to n8n
- [ ] MISP enrichment returns expected data
- [ ] Threat levels classified correctly
- [ ] Slack notifications formatted properly
- [ ] Firewall API calls succeed
- [ ] PostgreSQL records complete data
- [ ] Error handling works gracefully

## Security Policy

### Reporting Vulnerabilities

**DO NOT** create public issues for security vulnerabilities.

Instead, email: security@lucidityconsult.net

Include:
- Description of vulnerability
- Steps to reproduce
- Potential impact
- Suggested fix (if any)

### Sensitive Data

**Never commit:**
- API keys or passwords
- IP addresses of real systems
- Hostnames or domain names
- Any personally identifiable information

Use placeholders like:
- `YOUR_MISP_HOST`
- `YOUR_API_KEY`
- `192.168.1.x` or `10.0.0.x`

## Code of Conduct

- Be respectful and inclusive
- Focus on constructive feedback
- Help others learn
- Accept different viewpoints

## Questions?

- Open a Discussion on GitHub
- Check existing Issues
- Review documentation

## License

By contributing, you agree that your contributions will be licensed under the MIT License.

---

Thank you for helping make security automation accessible to everyone! 🛡️
