# 🛡️ Sentinel Detection Engineering

A **configuration-driven**, multi-organization system for creating and deploying Microsoft Sentinel detection rules using Infrastructure as Code (Bicep) and GitOps practices.

## 🎯 Quick Start

### 🚀 Create a New Detection Rule

**Portal-First Approach (Recommended)**

1. **Create in Azure Sentinel Portal** - Use the GUI to create and test your rule
   - This is the safest and most reliable method
   - Avoids configuration errors and syntax issues
   - Provides immediate testing and validation

2. **Run Manual Sync** - Go to Actions → **Manual Sync from Sentinel** → **Run workflow**

3. **Fill in the form**:
   - Environment: `dev` (for testing)
   - Organization: Select your organization (e.g., `org1`, `org2`)
   - Rule name: Leave empty to sync all rules, or specify a specific rule
   - Force sync: `false` (default)

4. **Submit** - This will:
   - Create a feature branch automatically
   - Export your rule from Sentinel portal
   - Generate KQL and Bicep files
   - Create a pull request for review

### 🔍 Review and Validate

1. **Review the PR** - Check the KQL logic and configuration
2. **Test in dev** - The rule is automatically deployed to dev environment
3. **Validate alerts** - Check that the rule generates appropriate alerts
4. **Approve and merge** - Once validated, merge the PR

### 🚀 Production Deployment

- **Automatic** - When the PR is merged to main, the rule automatically deploys to production
- **Safe** - Production deployment requires approval through GitHub environments

## 🏗️ Architecture

### Configuration-Driven Multi-Organization Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Configuration Layer                      │
│  config/organizations.json - Centralized org management    │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                 Organization Structure                      │
│  organizations/org1/  organizations/org2/  organizations/org3/ │
│  ├── env/           ├── env/           ├── env/           │
│  ├── kql/dev/       ├── kql/dev/       ├── kql/dev/       │
│  └── kql/prod/      └── kql/prod/      └── kql/prod/      │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                  Automated Workflows                        │
│  • Manual Sync (Portal → Repo)                             │
│  • Nightly Sync (Prod → Repo)                              │
│  • Drift Detection (Weekly)                                │
│  • Vendor Rule Export (Daily)                              │
└─────────────────────────────────────────────────────────────┘
```

### GitOps Workflow

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Create Rule   │───▶│  Feature Branch │───▶│  Pull Request   │
│   (Portal)      │    │   (Auto-gen)    │    │   (Auto-created)│
└─────────────────┘    └─────────────────┘    └─────────────────┘
                                                       │
                                                       ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Production    │◀───│   Merge to Main │◀───│  Validate in Dev│
│   Deployment    │    │   (Manual)      │    │   (Auto-deploy) │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

### Workflow Triggers

- **Manual Sync**: Portal changes → Feature branch → PR
- **Nightly Sync**: Production changes → Feature branch → PR (custom rules)
- **Nightly Sync**: Production changes → Main branch (vendor rules)
- **Deployment**: Feature branches → Dev, Main → Prod
- **Drift Detection**: Weekly checks → Feature branch with report

### File Structure

```
├── .github/workflows/
│   ├── deploy.yml              # Main deployment workflow
│   ├── manual-sync.yml         # Manual sync workflow
│   ├── nightly-sync.yml        # Nightly sync workflow
│   ├── drift-check.yml         # Drift detection workflow
│   └── vendor-sync.yml         # Vendor rule export workflow
├── config/
│   └── organizations.json      # Centralized organization configuration
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
├── scripts/
│   ├── ConfigManager.ps1       # Configuration management module
│   ├── sync-sentinel-changes.ps1 # Portal-to-repo sync script
│   ├── test-config.ps1         # Test configuration system
│   ├── deploy-with-config.ps1  # Example deployment script
│   ├── test-org-structure.ps1  # Test organizational structure
│   ├── validate-kql-columns.ps1 # KQL validation
│   ├── export_enabled_rules.ps1 # Export vendor rules
│   └── detect_drift.ps1         # Detect configuration drift
└── docs/
    ├── configuration-system.md  # Configuration system guide
    ├── review-process.md        # Review process documentation
    ├── creating-your-first-rule.md # Rule creation guide
    ├── approvals.md             # Approval process guide
    ├── naming-and-metadata.md   # Naming conventions
    └── pipeline-summary.md      # Pipeline overview
```

## 🏢 Multi-Organization Support

This repository supports multiple organizations/clients in a **scalable, configuration-driven way**:

### Configuration-Driven Architecture
- **Centralized Configuration**: All organization settings are defined in `config/organizations.json`
- **Scalable Structure**: Organizations are stored in `organizations/` directory
- **Environment Management**: Each organization can have different dev/prod configurations
- **Flexible Deployment**: Organizations can be enabled/disabled per environment

### Organization Configuration
The `config/organizations.json` file defines all organization settings:

```json
{
  "organizations": [
    {
      "name": "org1",
      "displayName": "Organization 1",
      "description": "First client organization",
      "environments": {
        "dev": {
          "resourceGroup": "sentinel-rg-dev",
          "workspaceName": "sentinel-ws-dev",
          "enabled": true
        },
        "prod": {
          "resourceGroup": "sentinel-rg-prod",
          "workspaceName": "sentinel-ws-prod", 
          "enabled": true
        }
      },
      "settings": {
        "syncVendorRules": true,
        "syncCustomRules": true,
        "createFeatureBranches": true
      }
    }
  ],
  "globalSettings": {
    "defaultEnvironment": "dev",
    "syncSchedule": "0 2 * * *",
    "maxConcurrentDeployments": 3,
    "enableDryRun": false
  }
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

### Configuration Management Scripts
- **`scripts/ConfigManager.ps1`**: PowerShell module for configuration management
- **`scripts/test-config.ps1`**: Validates configuration and file structure
- **`scripts/deploy-with-config.ps1`**: Example deployment using configuration system

## 🔄 Automated Workflows

### 1. Manual Sync Workflow (`manual-sync.yml`)
**Purpose**: Sync changes from Azure Sentinel portal back to repository
- **Trigger**: Manual via GitHub Actions
- **Inputs**: Environment (dev/prod), Organization, Rule name (optional), Force sync
- **Process**: Exports current rules and updates KQL/Bicep files
- **Use Case**: Reviewers make changes in portal, sync back to repo
- **Output**: Creates feature branch and pull request

### 2. Nightly Sync Workflow (`nightly-sync.yml`)
**Purpose**: Keep repository in sync with production Sentinel workspace
- **Schedule**: Daily at 2 AM UTC
- **Process**: 
  - Syncs vendor rules directly to main branch
  - Syncs custom rules via feature branch/PR for review
- **Benefits**: Catches manual changes, maintains consistency
- **Multi-org**: Processes all enabled organizations

### 3. Drift Detection Workflow (`drift-check.yml`)
**Purpose**: Detect differences between code and deployed state
- **Schedule**: Weekly on Sundays at 3 AM UTC
- **Process**: Compares Bicep templates with actual workspace state
- **Output**: Creates feature branch with drift report if issues found
- **Environments**: Checks both dev and prod workspaces

### 4. Vendor Rule Export Workflow (`vendor-sync.yml`)
**Purpose**: Track vendor rules (Microsoft and partners) across organizations
- **Schedule**: Daily at 2 AM UTC
- **Process**: Exports enabled vendor rules for visibility
- **Output**: Creates pull request with vendor rule updates
- **Benefits**: Maintains inventory of vendor rules

### 5. Deployment Workflow (`deploy.yml`)
**Purpose**: Deploy detection rules to environments
- **Trigger**: Push to main (prod) or feature branches (dev), pull requests
- **Process**: Validates and deploys Bicep templates
- **Environments**: 
  - Feature branches → Dev only
  - Main branch → Prod only (with approval)
- **Multi-org**: Deploys to all enabled organizations

## 🔧 How It Works

### 1. Rule Creation
- **Azure Sentinel Portal** - Create rules directly in the portal (easier GUI, safer)
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

**⚠️ Not Recommended** - Use the portal-first approach instead to avoid configuration errors.

If you must create rules manually (advanced users only):

```bash
# Create KQL file in the appropriate organization/environment directory
echo "your KQL query" > organizations/org1/kql/dev/my-rule.kql

# Create Bicep configuration in the environment directory
# Create pull request manually
# Deploy to dev for testing
```

### Sync from Portal

```bash
# Run manual sync workflow from GitHub Actions
# Go to Actions → Manual Sync from Sentinel
# Fill in the form:
# - Environment: dev (for testing)
# - Organization: org1 (or your org)
# - Rule name: (leave empty for all rules)
# - Force sync: false
```

### Configuration Management

```powershell
# Import the configuration module
. .\scripts\ConfigManager.ps1

# Get all organizations
$orgs = Get-Organizations

# Get specific organization
$org1 = Get-OrganizationByName -Name "org1"

# Get enabled organizations for dev environment
$enabledOrgs = Get-EnabledOrganizations -Environment "dev"
```

## 🔍 Validation and Testing

### KQL Validation
- **Syntax Check** - Bicep validates KQL syntax during build
- **Column Analysis** - Scripts detect entity mappings and custom details
- **Query Testing** - Test queries in Azure Sentinel Logs

### Configuration Validation
- **Structure Check** - Validates organization configuration
- **File Structure** - Ensures required directories and files exist
- **Environment Settings** - Validates environment configurations

### Deployment Validation
- **Bicep Build** - Templates are validated before deployment
- **What-if Analysis** - Preview changes before applying
- **Azure Validation** - ARM template validation against Azure

## 🚨 Troubleshooting

### Common Issues

1. **Configuration Errors**
   - Run `pwsh -File scripts/test-config.ps1` to validate
   - Check JSON syntax in `config/organizations.json`
   - Verify organization directory structure

2. **KQL Syntax Errors**
   - Check the query in Azure Sentinel Logs
   - Validate regex patterns and functions

3. **Deployment Failures**
   - Check Bicep build output
   - Verify Azure permissions
   - Review what-if analysis

4. **Sync Issues**
   - Check Azure authentication
   - Verify workspace names and resource groups
   - Review sync workflow logs

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

**🎯 Goal**: Make detection engineering accessible to beginners while maintaining enterprise-grade security practices through automation, GitOps, and configuration-driven multi-organization management.

