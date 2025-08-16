# Automation Scripts

This directory contains PowerShell scripts for automating Microsoft Sentinel detection engineering tasks.

## Scripts Overview

### `export_enabled_rules.ps1`
Exports all enabled detection rules from a Microsoft Sentinel workspace to JSON files.

**Usage:**
```powershell
# Set environment variables
$env:SUBSCRIPTION_ID = "your-subscription-id"
$env:RESOURCE_GROUP = "your-resource-group"
$env:WORKSPACE = "your-workspace-name"

# Run export
.\scripts\export_enabled_rules.ps1
```

**Output:** JSON files in `rules/vendor/enabled/` with format: `{resourceName}__{safeDisplayName}.json`

### `detect_drift.ps1`
Compares desired state (Bicep templates) with actual state (Sentinel workspace) and reports differences.

**Usage:**
```powershell
# Set environment variables
$env:SUBSCRIPTION_ID = "your-subscription-id"
$env:RESOURCE_GROUP = "your-resource-group"
$env:WORKSPACE = "your-workspace-name"

# Run drift detection
.\scripts\detect_drift.ps1
```

**Output:** `drift-report.md` with detailed comparison results

## Prerequisites

- Azure CLI installed and authenticated
- PowerShell 7+ (recommended)
- Azure PowerShell module (`Az`)

## Environment Variables

| Variable | Description | Required |
|----------|-------------|----------|
| `SUBSCRIPTION_ID` | Azure subscription ID | Yes |
| `RESOURCE_GROUP` | Resource group containing Sentinel workspace | Yes |
| `WORKSPACE` | Log Analytics workspace name | Yes |
| `API_VERSION` | API version (defaults to 2025-06-01) | No |

## Authentication

Scripts use Azure CLI authentication via `Get-AzAccessToken`. Ensure you're logged in:

```powershell
az login
az account set --subscription "your-subscription-id"
```

## Error Handling

- Scripts exit with code 1 on critical errors
- Warnings are logged but don't stop execution
- Detailed error messages are provided for troubleshooting

## Integration

These scripts are designed to work with GitHub Actions workflows:

- `export_enabled_rules.ps1` - Used in `vendor-sync.yml`
- `detect_drift.ps1` - Used in `drift-check.yml`

## Troubleshooting

### Common Issues

1. **Authentication Failed**
   - Ensure Azure CLI is logged in
   - Check subscription access
   - Verify OIDC setup for GitHub Actions

2. **API Errors**
   - Verify API version compatibility
   - Check workspace permissions
   - Ensure resource group exists

3. **Bicep Build Failures**
   - Validate Bicep syntax
   - Check for missing dependencies
   - Verify parameter files

### Debug Mode

Add `-Verbose` to see detailed execution:

```powershell
.\scripts\export_enabled_rules.ps1 -Verbose
```
