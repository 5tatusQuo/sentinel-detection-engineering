# 🛡️ Sentinel Detection Engineering

A **configuration-driven**, multi-organization system for creating and deploying Microsoft Sentinel detection rules using Infrastructure as Code (Bicep) and GitOps practices.

## 🚀 Quick Start

### Create a New Detection Rule

1. **Create in Azure Sentinel Portal** - Use the GUI to create and test your rule
2. **Run Drift Detection & Sync** - Go to Actions → **Drift Detection & Sync** → **Run workflow**
3. **Fill in the form**:
   - Environment: `dev` (for testing)
   - Organization: Select your organization (e.g., `org1`, `org2`)
   - Rule name: Leave empty to sync all rules, or specify a specific rule
4. **Submit** - This will create a feature branch and pull request with your changes

### Review and Deploy

1. **Review the PR** - Check the KQL logic and configuration
2. **Test in dev** - The rule is automatically deployed to dev environment
3. **Approve and merge** - Once validated, merge the PR to deploy to production

## 🏗️ Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Create Rule   │───▶│ Drift Detection │───▶│  Feature Branch │
│   (Portal)      │    │ & Sync Workflow │    │   (Auto-gen)    │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                                                       │
                                                       ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Production    │◀───│   Merge to Main │◀───│  Pull Request   │
│   Deployment    │    │   (Manual)      │    │   (Auto-created)│
└─────────────────┘    └─────────────────┘    └─────────────────┘
                               │                       │
                               ▼                       ▼
                    ┌─────────────────┐    ┌─────────────────┐
                    │ GitOps Drift    │    │  Validate in Dev│
                    │ Detection       │    │   (Auto-deploy) │
                    └─────────────────┘    └─────────────────┘
```

## 🔄 Automated Workflows

| Workflow | Purpose | Trigger | Output |
|----------|---------|---------|---------|
| **Drift Detection & Sync** | Sync portal changes to Git | Manual + Nightly (3 AM) | Feature branch + PR |
| **Deploy** | Deploy rules to environments | Push to main/branches | Dev/Prod deployment |
| **Vendor Sync** | Export vendor rules | Daily (2 AM) | Vendor rule inventory |

## 🏢 Multi-Organization Support

This repository supports multiple organizations with centralized configuration:

### File Structure
```
├── config/organizations.json      # Centralized org configuration
├── organizations/                 # Multi-organization support
│   ├── org1/                     # Organization 1
│   │   ├── env/                  # Environment configs
│   │   └── kql/                  # KQL queries (dev/prod)
│   └── org2/                     # Organization 2
├── .github/workflows/            # 3 streamlined workflows
├── scripts/                      # 5 PowerShell automation scripts
└── docs/                         # Detailed documentation
```

### Adding a New Organization
1. Add to `config/organizations.json`
2. Create directory structure: `organizations/orgX/{env,kql/{dev,prod}}`
3. Add Bicep files and KQL queries
4. Run `pwsh -File scripts/validate-bicep.ps1` to validate

## 📚 Documentation

For detailed information, see the docs folder:

- **[Configuration System](docs/configuration-system.md)** - Multi-organization setup
- **[Creating Your First Rule](docs/creating-your-first-rule.md)** - Step-by-step guide
- **[Review Process](docs/review-process.md)** - PR review workflow
- **[Pipeline Summary](docs/pipeline-summary.md)** - Workflow details
- **[Troubleshooting](docs/troubleshooting.md)** - Common issues and solutions

## 🛠️ Scripts Reference

| Script | Purpose |
|--------|---------|
| `ConfigManager.ps1` | Configuration management |
| `deploy-organizations.ps1` | Deploy to all organizations |
| `export_enabled_rules.ps1` | Export vendor rules |
| `sync-sentinel-changes.ps1` | Drift detection & sync |
| `validate-bicep.ps1` | Bicep validation |

## 🚨 Quick Troubleshooting

- **Configuration errors**: Run `pwsh -File scripts/validate-bicep.ps1`
- **KQL syntax errors**: Test queries in Azure Sentinel Logs
- **Deployment failures**: Check Bicep build output and Azure permissions
- **Sync issues**: Verify Azure authentication and workspace configuration

## 🤝 Contributing

1. Create rules in Azure Sentinel Portal
2. Use Drift Detection & Sync workflow to pull changes
3. Review and test in dev environment
4. Merge PR to deploy to production

---

**🎯 Goal**: Make detection engineering accessible through automation, GitOps, and configuration-driven multi-organization management.

For detailed guides and advanced usage, see the [docs](docs/) folder.