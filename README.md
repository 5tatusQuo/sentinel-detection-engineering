# Microsoft Sentinel Detection Engineering Repository

Welcome! This repository helps you manage Microsoft Sentinel detection rules using Infrastructure as Code (IaC). It's designed to be beginner-friendly while providing enterprise-grade automation.

## 🎯 What This Repository Does

This repository automates the deployment and management of Microsoft Sentinel detection rules. Think of it as a "recipe book" for security detection that:

- **Automatically deploys** detection rules to your Sentinel workspaces
- **Tracks changes** in Git so you can see what was deployed when
- **Prevents mistakes** with validation and testing
- **Makes it easy** to add new detection rules

## 🚀 Quick Start for Beginners

### Your First Detection Rule

Want to add a new security detection? Here's how:

1. **Create a KQL query** in the `kql/` folder
2. **Add it to the rules list** in `env/deploy-dev.bicep` 
3. **Test it locally** (see below)
4. **Create a Pull Request** - it will automatically deploy to Dev!

### Local Testing (Before You Deploy)

```bash
# Test that your Bicep files are valid
az bicep build --file env/deploy-dev.bicep

# See what would be deployed (without actually deploying)
az deployment group what-if \
  --resource-group your-dev-resource-group \
  --template-file env/deploy-dev.bicep \
  --parameters env/params/dev.jsonc
```

## 📁 Repository Structure (What's What)

```
.
├─ env/                              # Environment-specific files
│  ├─ deploy-dev.bicep               # Dev environment rules
│  ├─ deploy-prod.bicep              # Prod environment rules  
│  └─ params/                        # Simple configuration files
│     ├─ dev.jsonc                   # Dev workspace settings
│     └─ prod.jsonc                  # Prod workspace settings
├─ infra/                            # Reusable building blocks
│  ├─ sentinel-rules.bicep           # Main deployment template
│  └─ modules/                       # Reusable components
│     └─ scheduledRule.bicep         # Template for one detection rule
├─ kql/                              # Your detection queries
│  ├─ uc-powershell-encoded.kql      # Example: PowerShell detection
│  ├─ suspicious-login-attempts.kql  # Example: Login attempts
│  └─ admin-account-anomaly.kql      # Example: Admin account detection
├─ rules/vendor/                     # Vendor rule management
│  ├─ enabled/                       # Rules from Microsoft/partners
│  └─ references/                    # Reference templates
├─ scripts/                          # Helper scripts
├─ .github/workflows/                # Automation pipelines
└─ docs/                            # Detailed documentation
```

## 🔧 Setup Required

### 1. GitHub Repository Secrets

You need to tell GitHub how to connect to your Azure environment. Add these secrets in your GitHub repository settings:

**Azure Connection:**
- `AZURE_TENANT_ID`: Your Azure tenant ID
- `AZURE_SUBSCRIPTION_ID`: Your Azure subscription ID  
- `AZURE_CLIENT_ID`: OIDC application client ID

**Sentinel Workspaces:**
- `SENTINEL_RG_DEV`: Resource group name for Dev workspace
- `SENTINEL_WS_DEV`: Workspace name for Dev environment
- `SENTINEL_RG_PROD`: Resource group name for Prod workspace
- `SENTINEL_WS_PROD`: Workspace name for Prod environment

### 2. Azure Resources

You'll need these Azure resources set up:
- **Log Analytics Workspaces** (with Sentinel enabled)
- **Resource Groups** for Dev and Prod
- **OIDC Application** for GitHub → Azure authentication

## 🔄 How the Automation Works

### Nightly Export (`vendor-sync.yml`)
- **What it does**: Downloads the latest vendor rules from your Sentinel workspaces
- **When**: Runs every day at 2 AM UTC
- **Why**: Keeps track of what vendor rules you have enabled

### Deployment (`deploy.yml`)
- **Dev**: Automatically deploys when you merge to main
- **Prod**: Requires manual approval (safety first!)
- **Includes**: Validation, testing, and verification

### Drift Detection (`drift-check.yml`)
- **What it does**: Compares what's in your code vs what's actually deployed
- **When**: Runs weekly on Sundays
- **Why**: Catches if someone manually changed something in Sentinel

## 📚 Documentation

- **[Pipeline Overview](docs/pipeline-summary.md)** - How the deployment pipeline works
- **[Naming and Metadata](docs/naming-and-metadata.md)** - How to name your rules and add metadata
- **[Approvals Process](docs/approvals.md)** - How to set up approval gates
- **[Creating Your First Rule](docs/creating-your-first-rule.md)** - Step-by-step guide for beginners

## 📋 Best Practices

### Rule Naming
Use this format: `[ORG] – <What You're Detecting> (T####[#.###])`
- Example: `[ORG] – Suspicious PowerShell (EncodedCommand) (T1059.001)`

### Metadata
- **ATT&CK mapping**: Include relevant tactics and techniques
- **Owner**: Set to 'Detection Engineering'
- **Data sources**: Document what logs you're querying

### Before You Submit
- [ ] ATT&CK techniques mapped
- [ ] Data sources verified
- [ ] Query syntax reviewed
- [ ] Incident configuration reviewed
- [ ] Dev environment tests attached

## 🆘 Need Help?

### Common Issues
- **Deployment fails**: Check the GitHub Actions logs for error details
- **Rule not working**: Verify your KQL query in Sentinel Logs
- **Validation errors**: Run `az bicep build` locally first

### Getting Support
- Create an issue in this repository
- Contact the Detection Engineering team
- Review the documentation in the `docs/` folder

## 🔄 Rollback (If Something Goes Wrong)

To undo a deployment:
1. Revert the problematic Pull Request
2. Create a new PR with the reverted changes
3. The pipeline will redeploy the previous working state

## 🎓 Learning Resources

- **[Microsoft Sentinel Documentation](https://docs.microsoft.com/en-us/azure/sentinel/)**
- **[KQL Query Language](https://docs.microsoft.com/en-us/azure/data-explorer/kusto/query/)**
- **[Bicep Templates](https://docs.microsoft.com/en-us/azure/azure-resource-manager/bicep/)**
- **[MITRE ATT&CK Framework](https://attack.mitre.org/)**

---

**Happy detecting! 🕵️‍♂️**
