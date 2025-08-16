# [ORG] Microsoft Sentinel Detection Engineering

This repository contains Microsoft Sentinel detection rules and deployment automation for [ORG].

## Overview

This repository manages Microsoft Sentinel detection rules using Infrastructure as Code (IaC) with Bicep templates. It provides:

- **Custom Detection Rules**: Authoritative Bicep templates in `rules/custom/`
- **Vendor Rule Management**: Automated export and tracking of vendor rules
- **Automated Deployment**: Dev → Approval → Prod pipeline with drift detection
- **GitOps Workflow**: All changes tracked in Git with rollback capabilities

## Quick Start

### Adding a New Detection Rule

1. Create a new Bicep file in `rules/custom/` following the naming convention: `[ORG] – <Thing Detected> (T####[#.###]).bicep`
2. Add parameters to `rules/custom/params/dev.jsonc` and `rules/custom/params/prod.jsonc`
3. Test locally: `az bicep build --file rules/custom/your-rule.bicep`
4. Create a PR - the pipeline will deploy to Dev automatically

### Local Testing

```bash
# Build and validate Bicep
az bicep build --file rules/custom/your-rule.bicep

# What-if deployment (Dev environment)
az deployment group what-if \
  --resource-group $SENTINEL_RG_DEV \
  --template-file rules/custom/your-rule.bicep \
  --parameters rules/custom/params/dev.jsonc
```

## Repository Secrets

Set these secrets in your GitHub repository:

### Azure Authentication
- `AZURE_TENANT_ID`: Your Azure tenant ID
- `AZURE_SUBSCRIPTION_ID`: Your Azure subscription ID  
- `AZURE_CLIENT_ID`: OIDC application client ID for GitHub → Azure authentication

### Sentinel Workspaces
- `SENTINEL_RG_DEV`: Resource group name for Dev workspace
- `SENTINEL_WS_DEV`: Workspace name for Dev environment
- `SENTINEL_RG_PROD`: Resource group name for Prod workspace
- `SENTINEL_WS_PROD`: Workspace name for Prod environment

## Repository Structure

```
.
├─ rules/
│  ├─ custom/                         # Authoritative Bicep for deploy
│  │  ├─ README.md
│  │  ├─ uc-powershell-encoded.bicep
│  │  └─ params/
│  │     ├─ dev.jsonc
│  │     └─ prod.jsonc
│  └─ vendor/
│     ├─ enabled/                     # Nightly export of running instances
│     └─ references/                  # Vendor template references
├─ scripts/                           # PowerShell automation scripts
├─ .github/workflows/                 # CI/CD pipelines
└─ docs/                             # Documentation
```

## Workflows

### Nightly Export (`vendor-sync.yml`)
- Exports enabled rules from Sentinel workspaces
- Creates PR with updated vendor rule snapshots
- Runs daily at 2 AM UTC

### Deployment (`deploy.yml`)
- **Dev**: Automatic deployment on merge to main
- **Prod**: Manual approval required via GitHub Environment protection
- Includes validation and smoke tests

### Drift Detection (`drift-check.yml`)
- Compares desired state (Bicep) vs actual state (Sentinel)
- Creates PR with drift report if differences found
- Runs weekly on Sundays

## Documentation

- [Pipeline Overview](docs/pipeline-summary.md) - How the deployment pipeline works
- [Naming and Metadata](docs/naming-and-metadata.md) - Rule naming conventions and metadata standards
- [Approvals Process](docs/approvals.md) - How to set up and use approval gates

## Conventions

### Rule Naming
- Format: `[ORG] – <Thing Detected> (T####[#.###])`
- Example: `[ORG] – Suspicious PowerShell (EncodedCommand) (T1059.001)`

### Metadata
- Include ATT&CK mapping in tactics/techniques
- Set owner to 'Detection Engineering'
- Record upstream lineage for forked rules

### PR Checklist
- [ ] ATT&CK techniques mapped
- [ ] Data sources verified
- [ ] Query syntax reviewed
- [ ] Incident configuration reviewed
- [ ] Dev environment tests attached

## Rollback

To rollback a deployment:
1. Revert the problematic PR
2. Create a new PR with the reverted changes
3. The pipeline will redeploy the previous working state

## Support

For questions or issues:
- Create an issue in this repository
- Contact the Detection Engineering team
- Review the documentation in the `docs/` folder
