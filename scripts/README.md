# Automation Scripts

This directory contains PowerShell scripts that help automate Microsoft Sentinel detection engineering tasks. These scripts are used by the GitHub Actions workflows to keep your detection rules in sync.

## 🛠️ What These Scripts Do

### `export_enabled_rules.ps1`
**What it does**: Downloads all the detection rules that are currently running in your Sentinel workspace and saves them as JSON files.

**Why you need it**: Keeps track of what vendor rules (from Microsoft and partners) you have enabled, so you can see what's running vs what's in your code.

**When it runs**: Every night at 2 AM via the `vendor-sync.yml` workflow

### `detect_drift.ps1`
**What it does**: Compares what's in your code vs what's actually deployed in Sentinel and reports any differences.

**Why you need it**: Catches if someone manually changed something in Sentinel that's not reflected in your code.

**When it runs**: Weekly on Sundays via the `drift-check.yml` workflow

### `validate-kql-columns.ps1`
**What it does**: Checks that your KQL queries actually return the columns you're referencing in entity mappings and custom details.

**Why you need it**: Prevents deployment errors when your KQL doesn't return the columns you expect.

**When it runs**: During validation in the deployment workflow

### `sync-sentinel-changes.ps1`
**What it does**: Exports current Sentinel alert rules and automatically updates KQL files and JSON configurations to match the portal state. Features intelligent GitOps drift detection.

**Why you need it**: 
- Allows reviewers to make changes in the Sentinel portal (easier GUI) and sync back to repository
- Automatically detects when rules exist in dev but are missing from prod (GitOps drift)
- Supports JSON-based rule configuration for easier programmatic updates
- Handles all Azure Sentinel entity mapping formats automatically

**Key Features**:
- **Smart Drift Detection**: Detects rules missing from production environment
- **New Rule Detection**: Automatically adds rules that exist in Sentinel but not in local configs
- **Entity Mapping Conversion**: Handles old and new entity mapping formats seamlessly
- **Environment Parity**: Maintains consistency between dev and prod configurations

**When it runs**: 
- Manually by reviewers during the review process
- Automatically every night for production sync
- Via manual sync workflows for both dev and prod environments
- Triggered by GitOps workflows when drift is detected

## 🚀 How to Use These Scripts

### Prerequisites
- **Azure CLI** installed and logged in
- **PowerShell 7+** (recommended)
- **Azure PowerShell module** (`Az`)

### Setting Up Environment Variables

Before running scripts, set these environment variables:

```powershell
# Your Azure subscription details
$env:SUBSCRIPTION_ID = "your-subscription-id"
$env:RESOURCE_GROUP = "your-resource-group-name"
$env:WORKSPACE = "your-workspace-name"

# Optional: API version (defaults to 2025-06-01)
$env:API_VERSION = "2025-06-01"
```

### Running the Scripts

#### Export Enabled Rules
```powershell
# Export all enabled rules from your workspace
.\scripts\export_enabled_rules.ps1
```

**Output**: JSON files in `rules/vendor/enabled/` with names like `{resourceName}__{safeDisplayName}.json`

#### Detect Drift
```powershell
# Compare code vs deployed state
.\scripts\detect_drift.ps1
```

**Output**: `drift-report.md` with detailed comparison results

#### Validate KQL Columns
```powershell
# Validate KQL columns for a specific rule
pwsh scripts/validate-kql-columns.ps1 \
  -KqlFile kql/your-rule.kql \
  -EntityMappings '[{"entityType":"Account","fieldMappings":[{"identifier":"FullName","columnName":"SubjectUserName"}]}]' \
  -CustomDetails '{"CustomField":"ColumnName"}'
```

#### Sync Sentinel Changes
```powershell
# Sync all custom rules from dev environment for org1
.\scripts\sync-sentinel-changes.ps1 -ResourceGroup "sentinel-ws-dev" -WorkspaceName "sentinel-rg-dev" -Environment "dev" -Organization "org1"

# Sync specific rule only
.\scripts\sync-sentinel-changes.ps1 -ResourceGroup "sentinel-ws-dev" -WorkspaceName "sentinel-rg-dev" -Environment "dev" -Organization "org1" -RuleName "CustomRule3"

# Sync from production (detects drift automatically)
.\scripts\sync-sentinel-changes.ps1 -ResourceGroup "sentinel-ws-prod" -WorkspaceName "sentinel-rg-prod" -Environment "prod" -Organization "org1"

# Dry run to see what would change (no actual updates)
.\scripts\sync-sentinel-changes.ps1 -ResourceGroup "sentinel-ws-dev" -WorkspaceName "sentinel-rg-dev" -Environment "dev" -Organization "org1" -DryRun

# Force sync even if no changes detected
.\scripts\sync-sentinel-changes.ps1 -ResourceGroup "sentinel-ws-dev" -WorkspaceName "sentinel-rg-dev" -Environment "dev" -Organization "org1" -ForceSync
```

**New GitOps Output Example**:
```
🚨 GitOps Alert: 1 rules need deployment to prod
   - CustomRule3
💡 Create a PR to deploy these rules to production
```

## 🔐 Authentication

The scripts use Azure CLI authentication. Make sure you're logged in:

```powershell
# Login to Azure
az login

# Set your subscription
az account set --subscription "your-subscription-id"
```

## 🔄 Integration with GitHub Actions

These scripts are automatically used by the GitHub Actions workflows:

- **`vendor-sync.yml`** uses `export_enabled_rules.ps1` to sync vendor rules
- **`drift-check.yml`** uses `detect_drift.ps1` to check for drift
- **`deploy.yml`** uses `validate-kql-columns.ps1` during validation
- **Reviewers** use `sync-sentinel-changes.ps1` to sync portal changes back to repository

## 🆘 Troubleshooting

### Common Issues

#### 1. Authentication Failed
**Symptoms**: "Login failed" or "Access denied" errors

**Solutions**:
- Make sure Azure CLI is logged in: `az login`
- Check you have access to the subscription: `az account show`
- Verify your account has the right permissions on the workspace

#### 2. API Errors
**Symptoms**: "Bad Request" or "Resource not found" errors

**Solutions**:
- Check the API version is correct
- Verify the workspace name and resource group exist
- Make sure Sentinel is enabled on the workspace

#### 3. Bicep Build Failures
**Symptoms**: "Invalid template" or syntax errors

**Solutions**:
- Run `az bicep build` locally first to catch syntax errors
- Check for missing properties in your rule objects
- Verify all referenced files exist

### Debug Mode

Add `-Verbose` to see detailed execution:

```powershell
# See detailed output
.\scripts\export_enabled_rules.ps1 -Verbose
.\scripts\detect_drift.ps1 -Verbose
```

### Getting Help

If you're stuck:
1. Check the GitHub Actions logs for error details
2. Run the script locally with `-Verbose` to see what's happening
3. Create an issue in this repository
4. Contact the Detection Engineering team

## 📋 Script Output Examples

### Export Script Output
```
Exporting enabled rules from workspace: sentinel-ws-dev
Found 15 enabled rules
Exported: rules/vendor/enabled/Microsoft_Defender_for_Cloud__Suspicious_Activity.json
Exported: rules/vendor/enabled/Microsoft_Sentinel__Brute_Force_Attack.json
...
Export completed successfully
```

### Drift Detection Output
```
Comparing desired state vs actual state...
Found 2 rules with differences:
- Rule 'uc-powershell-encoded': Severity changed from 'Medium' to 'High'
- Rule 'uc-suspicious-login': Query frequency changed from 'PT1H' to 'PT30M'
Drift report saved to: drift-report.md
```

---

**Need help? Check the main README or create an issue! 🆘**
