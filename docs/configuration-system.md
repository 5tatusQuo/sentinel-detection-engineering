# Configuration System

## Overview

The repository now uses a **configuration-driven architecture** for managing multiple organizations. This provides:

- **Centralized Management**: All organization settings in one place
- **Scalability**: Easy to add new organizations without code changes
- **Flexibility**: Environment-specific configurations per organization
- **Maintainability**: No hardcoded values in workflows or scripts

## Configuration File

The main configuration is stored in `config/organizations.json`:

```json
{
  "organizations": [
    {
      "name": "org1",
      "displayName": "Organization 1",
      "description": "First client organization",
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

## PowerShell Module

The `scripts/ConfigManager.ps1` module provides functions for working with the configuration:

### Key Functions

- `Get-OrganizationConfig`: Load the configuration file
- `Get-Organizations`: Get all organizations
- `Get-OrganizationByName`: Get specific organization
- `Get-OrganizationEnvironment`: Get environment settings for an organization
- `Get-EnabledOrganizations`: Get organizations with enabled environments
- `Get-OrganizationPaths`: Get file paths for an organization
- `Test-OrganizationConfig`: Validate configuration structure

### Usage Examples

```powershell
# Import the module
. .\scripts\ConfigManager.ps1

# Get all organizations
$orgs = Get-Organizations

# Get specific organization
$org1 = Get-OrganizationByName -Name "org1"

# Get environment settings
$env = Get-OrganizationEnvironment -OrganizationName "org1" -Environment "dev"

# Get file paths
$paths = Get-OrganizationPaths -OrganizationName "org1" -Environment "dev"

# Loop through enabled organizations
$enabledOrgs = Get-EnabledOrganizations -Environment "dev"
foreach ($org in $enabledOrgs) {
    Write-Host "Processing $($org.name)"
}
```

## Adding a New Organization

1. **Add to Configuration**:
   ```json
   {
     "name": "org3",
     "displayName": "Organization 3",
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
   ```

2. **Create Directory Structure**:
   ```bash
   mkdir -p organizations/org3/{env,kql/{dev,prod}}
   ```

3. **Add Bicep Files**:
   - `organizations/org3/env/deploy-dev.bicep`
   - `organizations/org3/env/deploy-prod.bicep`

4. **Add KQL Files**:
   - Place KQL files in `organizations/org3/kql/dev/` and `organizations/org3/kql/prod/`

5. **Test Configuration**:
   ```bash
   pwsh -File scripts/validate-bicep.ps1
   ```

## Testing

### Validate Configuration
```bash
pwsh -File scripts/validate-bicep.ps1
```

### Test Deployment Pattern
```bash
pwsh -File scripts/deploy-organizations.ps1 -Environment "dev"
```

## Benefits

### For Developers
- **No Code Changes**: Add organizations by updating JSON configuration
- **Consistent Patterns**: Standardized deployment and sync patterns
- **Validation**: Built-in configuration validation
- **Documentation**: Self-documenting configuration structure

### For Operations
- **Centralized Management**: All settings in one place
- **Environment Control**: Enable/disable environments per organization
- **Scalability**: Easy to add new clients
- **Maintainability**: Clear separation of configuration and code

### For CI/CD
- **Dynamic Discovery**: Workflows automatically discover organizations
- **Environment Awareness**: Deploy only to enabled environments
- **Error Prevention**: Configuration validation prevents deployment errors
- **Flexibility**: Support for different resource groups per organization

## Migration from Hardcoded Approach

The configuration system replaces the previous hardcoded approach:

### Before (Hardcoded)
```yaml
# Workflow with hardcoded organization names
- name: Deploy org1
  run: az deployment group create --resource-group org1-rg --template-file org1/env/deploy-dev.bicep

- name: Deploy org2  
  run: az deployment group create --resource-group org2-rg --template-file org2/env/deploy-dev.bicep
```

### After (Configuration-Driven)
```powershell
# Script using configuration system
$enabledOrgs = Get-EnabledOrganizations -Environment "dev"
foreach ($org in $enabledOrgs) {
    $env = Get-OrganizationEnvironment -OrganizationName $org.name -Environment "dev"
    $paths = Get-OrganizationPaths -OrganizationName $org.name -Environment "dev"
    az deployment group create --resource-group $env.resourceGroup --template-file $paths.BicepPath
}
```

## Future Enhancements

- **Environment Variables**: Support for environment-specific secrets
- **Validation Rules**: Custom validation rules per organization
- **Deployment Strategies**: Different deployment strategies per organization
- **Monitoring**: Configuration-driven monitoring and alerting
- **Templates**: Organization templates for quick setup
