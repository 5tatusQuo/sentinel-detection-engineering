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
│   ├── manual-sync.yml         # Manual sync workflow
│   └── nightly-sync.yml        # Nightly sync workflow
├── config/
│   └── organizations.json      # Organization configuration
├── organizations/              # All client organizations
│   ├── org1/                   # Organization 1 (Client 1)
│   │   ├── env/
│   │   │   ├── deploy-dev.bicep    # Dev environment rules
│   │   │   └── deploy-prod.bicep   # Prod environment rules
│   │   └── kql/                    # KQL query files
│   │       ├── dev/                # Dev environment KQL files
│   │       │   ├── suspicious-login-attempts.kql
│   │       │   ├── admin-account-anomaly.kql
│   │       │   └── uc-powershell-encoded.kql
│   │       └── prod/               # Prod environment KQL files
│   └── org2/                   # Organization 2 (Client 2)
│       ├── env/
│       │   ├── deploy-dev.bicep    # Dev environment rules
│       │   └── deploy-prod.bicep   # Prod environment rules
│       └── kql/                    # KQL query files
│           ├── dev/                # Dev environment KQL files
│           └── prod/               # Prod environment KQL files
├── infra/
│   ├── sentinel-rules.bicep    # Root orchestrator
│   └── modules/
│       └── scheduledRule.bicep # Reusable rule module
└── scripts/
    ├── ConfigManager.ps1       # Configuration management module
    ├── sync-sentinel-changes.ps1 # Portal-to-repo sync script
    ├── test-config.ps1         # Test configuration system
    ├── deploy-with-config.ps1  # Example deployment script
    ├── test-org-structure.ps1  # Test organizational structure
    ├── validate-kql-columns.ps1 # KQL validation
    ├── export_enabled_rules.ps1 # Export vendor rules
    └── detect_drift.ps1         # Detect configuration drift
```

## 🏢 Multi-Organization Support

This repository supports multiple organizations/clients in a scalable, configuration-driven way:

### Configuration-Driven Architecture
- **Centralized Configuration**: All organization settings are defined in `config/organizations.json`
- **Scalable Structure**: Organizations are stored in `organizations/` directory
- **Environment Management**: Each organization can have different dev/prod configurations
- **Flexible Deployment**: Organizations can be enabled/disabled per environment

### Organization Structure
```
organizations/
├── org1/                    # Organization 1
│   ├── env/
│   │   ├── deploy-dev.bicep
│   │   └── deploy-prod.bicep
│   └── kql/
│       ├── dev/             # Dev environment KQL files
│       └── prod/            # Prod environment KQL files
└── org2/                    # Organization 2
    ├── env/
    │   ├── deploy-dev.bicep
    │   └── deploy-prod.bicep
    └── kql/
        ├── dev/             # Dev environment KQL files
        └── prod/            # Prod environment KQL files
```

### Configuration Management
The `config/organizations.json` file defines all organization settings:

```json
{
  "organizations": [
    {
      "name": "org1",
      "displayName": "Organization 1",
      "environments": {
        "dev": {
          "resourceGroup": "sentinel-ws-dev",
          "workspaceName": "sentinel-rg-dev",
          "enabled": true
        },
        "prod": {
          "resourceGroup": "sentinel-ws-prod",
          "workspaceName": "sentinel-rg-prod", 
          "enabled": true
        }
      }
    }
  ]
}
```

### Adding a New Organization
1. **Add to Configuration**: Add the organization to `config/organizations.json`
2. **Create Directory Structure**: 
   ```bash
   mkdir -p organizations/org3/{env,kql/{dev,prod}}
   ```
3. **Create Bicep Files**: Add `deploy-dev.bicep` and `deploy-prod.bicep` in `organizations/org3/env/`
4. **Add KQL Files**: Place KQL files in `organizations/org3/kql/dev/` and `organizations/org3/kql/prod/`
5. **Test Configuration**: Run `pwsh -File scripts/test-config.ps1` to validate

### Configuration Scripts
- **`scripts/ConfigManager.ps1`**: PowerShell module for configuration management
- **`scripts/test-config.ps1`**: Validates configuration and file structure
- **`scripts/deploy-with-config.ps1`**: Example deployment using configuration system

### Organization-Specific Operations
- **Manual Sync**: Specify organization in the workflow parameters
- **Nightly Sync**: Automatically processes all organizations
- **Deployment**: Deploys all organizations to their respective environments

## 🔧 How It Works

### 1. Rule Creation
- **Azure Sentinel Portal** - Create rules directly in the portal (easier GUI)
- **Manual Sync Workflow** - Run sync workflow to pull changes to repository
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
# Create KQL file in the appropriate environment directory
echo "your KQL query" > organizations/org1/kql/dev/my-rule.kql

# Create rule in Azure Sentinel portal
# Then run manual sync workflow to pull changes to repository
```

### Sync from Portal

```bash
# Run manual sync workflow from GitHub Actions
# Go to Actions → Manual Sync from Sentinel
# Select environment and options
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
