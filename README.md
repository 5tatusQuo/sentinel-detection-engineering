# 🛡️ Sentinel Detection Engineering

A beginner-friendly, automated system for creating and deploying Microsoft Sentinel detection rules using Infrastructure as Code (Bicep) and GitOps practices.

## 🎯 Quick Start

### 🚀 Create a New Detection Rule (Recommended)

1. **Go to Actions** → **Create Rule Pull Request** → **Run workflow**
2. **Fill in the form**:
   - Rule name (e.g., `suspicious-login-attempts`)
   - Display name (e.g., `Suspicious Login Attempts`)
   - Severity (Low/Medium/High/Critical)
   - MITRE ATT&CK tactics and techniques
   - Your KQL query
3. **Submit** - This will:
   - Create a feature branch
   - Generate the KQL file
   - Add rule configurations to both dev and prod
   - Create a pull request
   - Deploy to dev environment for testing

### 🔍 Review and Validate

1. **Review the PR** - Check the KQL logic and configuration
2. **Test in dev** - The rule is automatically deployed to dev environment
3. **Validate alerts** - Check that the rule generates appropriate alerts
4. **Approve and merge** - Once validated, merge the PR

### 🚀 Production Deployment

- **Automatic** - When the PR is merged to main, the rule automatically deploys to production
- **Safe** - Production deployment requires approval through GitHub environments

## 🏗️ Architecture

### GitOps Workflow

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Create Rule   │───▶│  Feature Branch │───▶│  Pull Request   │
│   (GitHub UI)   │    │   (Auto-gen)    │    │   (Auto-created)│
└─────────────────┘    └─────────────────┘    └─────────────────┘
                                                       │
                                                       ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Production    │◀───│   Merge to Main │◀───│  Validate in Dev│
│   Deployment    │    │   (Manual)      │    │   (Auto-deploy) │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

### File Structure

```
├── .github/workflows/
│   ├── deploy.yml              # Main deployment workflow
│   └── create-rule-pr.yml      # Rule creation workflow
├── env/
│   ├── deploy-dev.bicep        # Dev environment rules
│   ├── deploy-prod.bicep       # Prod environment rules
│   └── params/
│       ├── dev.jsonc           # Dev parameters
│       └── prod.jsonc          # Prod parameters
├── infra/
│   ├── sentinel-rules.bicep    # Root orchestrator
│   └── modules/
│       └── scheduledRule.bicep # Reusable rule module
├── kql/                        # KQL query files
│   ├── suspicious-login-attempts.kql
│   ├── admin-account-anomaly.kql
│   └── uc-powershell-encoded.kql
└── scripts/
    ├── generate-rule-config.ps1 # Rule generation script
    ├── new-rule.ps1            # Interactive rule creator
    └── validate-kql-columns.ps1 # KQL validation
```

## 🔧 How It Works

### 1. Rule Creation
- **GitHub Actions UI** - Fill out a form with rule details
- **Automated Analysis** - Script analyzes KQL to detect entity mappings and custom details
- **Branch Creation** - Creates a feature branch with all changes
- **Pull Request** - Automatically creates a PR for review

### 2. Development Testing
- **Auto-deploy to Dev** - Rule deploys to dev environment immediately
- **Validation** - Engineer tests the rule in Sentinel dev environment
- **Review Process** - Team reviews KQL logic and configuration

### 3. Production Deployment
- **Manual Approval** - Engineer approves and merges the PR
- **Auto-deploy to Prod** - Rule automatically deploys to production
- **Environment Protection** - Production deployment requires approval

## 🛠️ Advanced Usage

### Manual Rule Creation

If you prefer to create rules manually:

```bash
# Create KQL file
echo "your KQL query" > kql/my-rule.kql

# Generate configuration
pwsh scripts/generate-rule-config.ps1 \
  -KqlFile "kql/my-rule.kql" \
  -RuleName "my-rule" \
  -Severity "Medium" \
  -Environment "dev" \
  -Tactics "InitialAccess" \
  -Techniques "T1078"

# The script automatically adds the code to Bicep files
```

### Interactive Rule Creation

```bash
# Run interactive creator
pwsh scripts/new-rule.ps1
```

## 🔍 Validation and Testing

### KQL Validation
- **Syntax Check** - Bicep validates KQL syntax during build
- **Column Analysis** - Scripts detect entity mappings and custom details
- **Query Testing** - Test queries in Azure Sentinel Logs

### Deployment Validation
- **Bicep Build** - Templates are validated before deployment
- **What-if Analysis** - Preview changes before applying
- **Azure Validation** - ARM template validation against Azure

## 🚨 Troubleshooting

### Common Issues

1. **KQL Syntax Errors**
   - Check the query in Azure Sentinel Logs
   - Validate regex patterns and functions

2. **Deployment Failures**
   - Check Bicep build output
   - Verify Azure permissions
   - Review what-if analysis

3. **Missing Rules**
   - Check if rules exist in Sentinel
   - Verify Bicep configuration
   - Check deployment logs

### Getting Help

- **Documentation** - Check the `docs/` folder for detailed guides
- **Scripts** - Use validation scripts in `scripts/` folder
- **GitHub Issues** - Report problems in the repository

## 📚 Learning Resources

- [Microsoft Sentinel Documentation](https://docs.microsoft.com/en-us/azure/sentinel/)
- [KQL Quick Reference](https://docs.microsoft.com/en-us/azure/data-explorer/kql-quick-reference)
- [Bicep Documentation](https://docs.microsoft.com/en-us/azure/azure-resource-manager/bicep/)
- [MITRE ATT&CK Framework](https://attack.mitre.org/)

## 🤝 Contributing

1. **Create a feature branch** for your changes
2. **Follow the GitOps workflow** - create PR, test in dev, merge to main
3. **Update documentation** for any new features
4. **Test thoroughly** before merging

---

**🎯 Goal**: Make detection engineering accessible to beginners while maintaining enterprise-grade security practices through automation and GitOps.
