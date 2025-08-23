# Sentinel Detection Rules Infrastructure

This directory contains the "building blocks" for deploying Microsoft Sentinel detection rules across multiple organizations. Think of it as the engine that powers your scalable detection rule deployments.

## 🏗️ How It Works (Simple Version)

Instead of creating a separate file for each detection rule (which would be messy), we use a smart, scalable approach:

1. **Configuration System** (`config/organizations.json`) - Central configuration for all organizations and environments
2. **One main template** (`sentinel-rules.bicep`) - This is like a "rule factory" that creates multiple rules
3. **One reusable component** (`modules/scheduledRule.bicep`) - This is the "blueprint" for a single rule
4. **Organization files** (`organizations/orgX/env/deploy-*.bicep`) - These tell the factory what rules to make for each org/environment
5. **KQL files** (`organizations/orgX/kql/dev|prod/*.kql`) - These are your actual detection queries

## 🎯 Why This Approach?

✅ **Multi-Organization Support**: Manage rules for multiple clients from one repository
✅ **Configuration-Driven**: Centralized configuration makes adding new organizations simple
✅ **Environment Separation**: Separate dev/prod KQL files and settings per organization
✅ **Easy to add rules**: Just add one line to an array, not create new files
✅ **Consistent**: All rules follow the same pattern across all organizations
✅ **Maintainable**: Change one thing, it applies to all rules and organizations
✅ **Readable**: Your KQL queries are in separate files for easy review
✅ **Scalable**: Works whether you have 5 rules or 500 rules across multiple organizations  

## 📁 What's in Each File

```
config/
└── organizations.json            # Central configuration for all organizations

infra/
├── sentinel-rules.bicep          # The "rule factory" - creates multiple rules
├── modules/
│   └── scheduledRule.bicep       # The "blueprint" for one rule
├── README.md                     # This file

organizations/
└── org1/                         # Organization 1 (repeat for org2, org3, etc.)
    ├── env/
    │   ├── deploy-dev.bicep       # Dev environment rules list
    │   └── deploy-prod.bicep      # Prod environment rules list
    └── kql/
        ├── dev/                   # Development KQL queries
        │   ├── customrule1.kql    # Custom detection query
        │   └── ...
        └── prod/                  # Production KQL queries
            ├── customrule1.kql    # Same queries, prod-ready
            └── ...

scripts/
├── sync-sentinel-changes.ps1     # Sync rules from portal to Bicep
├── ConfigManager.ps1             # Organization configuration management
├── validate-bicep.ps1            # Bicep validation for all orgs
└── deploy-organizations.ps1      # Deploy to all organizations
```

## 🚀 Adding a New Rule (Step by Step)

### Step 1: Create Your KQL Query
Create a new file in the `kql/` folder with your detection query:

```kql
// kql/my-new-detection.kql
SecurityEvent
| where EventID == 4624
| where AccountType == "User"
| summarize count() by Account
| where count_ > 10
```

### Step 2: Add to Dev Environment
Add your rule to `env/deploy-dev.bicep`:

```bicep
// Load your KQL file
var kqlNewRule = loadTextContent('../kql/my-new-detection.kql')

var rules = [
  // ... existing rules ...
  {
    name: 'uc-my-new-detection'           // Unique identifier
    displayName: '[DEV] [ORG] – My New Detection'  // Name in Sentinel
    kql: kqlNewRule                       // Your KQL query
    severity: 'Medium'                     // How serious is this?
    enabled: true                          // Turn it on
    frequency: 'PT1H'                      // How often to run (every hour)
    period: 'PT1H'                         // How far back to look
    tactics: [ 'Execution' ]               // ATT&CK tactics
    techniques: [ 'T1059' ]                // ATT&CK techniques
    createIncident: false                  // Don't create incidents in dev
    grouping: {}                           // Use default grouping
    entities: {                            // What entities to extract
      accountFullName: 'Account'
    }
    customDetails: {}                      // No custom details for now
  }
]
```

### Step 3: Add to Prod Environment
Copy the same rule to `env/deploy-prod.bicep` but change:
- `displayName`: Change `[DEV]` to `[PROD]`
- `severity`: Maybe increase to `High`
- `createIncident`: Set to `true`

### Step 4: Test Locally
```bash
# Test that your files are valid
az bicep build --file env/deploy-dev.bicep

# See what would be deployed
az deployment group what-if \
  --resource-group your-dev-rg \
  --template-file env/deploy-dev.bicep \
  --parameters env/params/dev.jsonc
```

## ⚙️ Rule Configuration Options

### Required Settings
- `name` - Unique identifier (no spaces, use hyphens)
- `displayName` - What users see in Sentinel
- `kql` - Your detection query

### Optional Settings (with sensible defaults)
- `enabled` - Turn rule on/off (default: true)
- `severity` - How serious? (default: 'Medium')
- `frequency` - How often to run (default: 'PT1H' = every hour)
- `period` - How far back to look (default: 'PT1H' = last hour)
- `createIncident` - Create incidents? (default: true)
- `tactics` - ATT&CK tactics array (default: [])
- `techniques` - ATT&CK techniques array (default: [])

### Advanced Settings
- `grouping` - How to group alerts
- `entities` - What entities to extract
- `customDetails` - Custom fields to add to alerts

## 🔗 Entity Mapping

The system supports multiple entity mapping formats and automatically converts them for Azure Sentinel:

### Legacy Format (Auto-Converted)
```bicep
entities: {
  accountFullName: 'SubjectUserName'  // Simple column mapping
  hostName: 'Computer'                // Automatically converted to Azure format
}
```

### Azure Sentinel Format (Recommended)
```bicep
entities: {
  entityType: 'Account'
  fieldMappings: [{
    identifier: 'FullName'
    columnName: 'SubjectUserName'
  }]
}
```

### Multiple Entities (Array Format)
```bicep
entities: [
  {
    entityType: 'Account'
    fieldMappings: [{
      identifier: 'FullName'
      columnName: 'SubjectUserName'
    }]
  },
  {
    entityType: 'Host'
    fieldMappings: [{
      identifier: 'FullName'
      columnName: 'Computer'
    }]
  }
]
```

**Note**: The Bicep module automatically handles format conversion, so any format will work correctly during deployment.

## 📝 Custom Details

Add custom fields to your alerts:

```bicep
customDetails: {
  EncodedArgument: 'EncArg'           // Add custom field
  CommandLine: 'CommandLine'          // Add another custom field
}
```

## ⚙️ Configuration System

The repository uses a centralized configuration system to manage multiple organizations:

### config/organizations.json
```json
{
  "organizations": [
    {
      "name": "org1",
      "displayName": "Organization One",
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
      }
    }
  ]
}
```

### Adding a New Organization
1. **Add to Config**: Add a new organization entry to `config/organizations.json`
2. **Create Structure**: Create the folder structure under `organizations/neworg/`
3. **Set Enabled**: Set `enabled: true` for environments you want to deploy to
4. **Deploy**: The automated workflows will handle the rest

### PowerShell Scripts
- **`ConfigManager.ps1`**: Loads and validates the organization configuration
- **`deploy-organizations.ps1`**: Deploys to all enabled organizations
- **`validate-bicep.ps1`**: Validates Bicep files for all organizations
- **`sync-sentinel-changes.ps1`**: Syncs portal rules to Bicep files

## 🔄 Deployment

The GitHub Actions workflows automatically handle deployment:

### Automated Workflows
1. **Deploy**: Automatically deploys to all enabled organizations when Bicep files change
2. **Validate**: Validates all organization Bicep files before deployment
3. **Manual Sync**: Syncs rules from Azure Sentinel portal to Bicep files
4. **Vendor Sync**: Syncs vendor-built rules for all organizations

### Configuration-Driven Deployment
- **Central Config**: `config/organizations.json` defines all organizations and environments
- **Multi-Org Support**: Deploy to multiple organizations with different settings
- **Environment Separation**: Separate dev/prod deployments with different parameters

### Manual Deployment
```bash
# Deploy to all enabled organizations
pwsh -File scripts/deploy-organizations.ps1 -Environment 'prod'

# Or deploy specific organization
az deployment group create \
  --resource-group sentinel-ws-dev \
  --template-file organizations/org1/env/deploy-dev.bicep

# Validate all organization Bicep files
pwsh -File scripts/validate-bicep.ps1
```

## 🌍 Environment & Organization Differences

### Environment Differences (per Organization)
- **Dev Environment**:
  - Lower severity alerts
  - No incidents created (testing only)
  - Focus on validation and development
  - Separate KQL files in `organizations/orgX/kql/dev/`

- **Prod Environment**:
  - Higher severity alerts
  - Incidents created for response
  - Production-ready settings
  - Separate KQL files in `organizations/orgX/kql/prod/`

### Organization Differences
- **Resource Groups**: Each organization has different Azure resource groups
- **Workspace Names**: Different Log Analytics workspaces per organization
- **Settings**: Different business rules and alert configurations
- **KQL Files**: Organization-specific detection queries and thresholds

Each organization is configured in `config/organizations.json` with its own settings.

## 🆘 Common Issues

### Multi-Organization Issues

#### "Configuration file not found"
- **Error**: `Configuration file not found: config/organizations.json`
- **Fix**: Ensure the file exists and is committed to git (not ignored)
- **Check**: Run `git add config/organizations.json` if needed

#### "Organization not found in config"
- **Error**: `Organization 'org1' not found in configuration`
- **Fix**: Add the organization to `config/organizations.json`
- **Check**: Verify the organization name matches exactly

#### "Resource group/workspace mismatch"
- **Error**: Deployment fails due to wrong resource group/workspace
- **Fix**: Verify `config/organizations.json` has correct Azure resource names
- **Check**: Compare with actual Azure resources

### Bicep Template Issues

#### "Property doesn't exist" Error
Make sure all your rule objects have the same properties. If you don't need `grouping` or `customDetails`, use empty objects: `grouping: {}` and `customDetails: {}`

#### "KQL variable not defined"
- **Error**: `kqlCustomRule1` is not defined
- **Fix**: The sync script should generate KQL variable declarations automatically
- **Check**: Run the manual sync workflow to regenerate Bicep files

#### KQL Column Errors
If you reference columns in `entities` or `customDetails`, make sure those columns are actually returned by your KQL query.

#### Entity Mapping Deployment Errors
- **Error**: "Cannot deserialize JSON object into List<EntityMapping>"
- **Fix**: This is automatically handled by the Bicep module now
- **Cause**: Old entity mapping formats are automatically converted to Azure-compatible arrays

#### JSON Configuration Issues
- **Error**: Rule configurations not updating during sync
- **Fix**: The sync script now uses JSON-based configuration for easier updates
- **Check**: Verify `rules-dev.json` and `rules-prod.json` files exist and are valid

### Validation & Testing

#### Validation Errors
Run validation for all organizations:
```bash
pwsh -File scripts/validate-bicep.ps1
```

Or validate a specific organization:
```bash
az bicep build --file organizations/org1/env/deploy-dev.bicep
```

#### Test KQL Queries
Always test your KQL queries in the Azure Sentinel portal before deploying to avoid runtime errors.

---

**Need help? Check the main README or create an issue! 🆘**
