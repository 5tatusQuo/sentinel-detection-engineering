# Sentinel Detection Rules Infrastructure

This directory contains the "building blocks" for deploying Microsoft Sentinel detection rules. Think of it as the engine that powers your detection rule deployments.

## 🏗️ How It Works (Simple Version)

Instead of creating a separate file for each detection rule (which would be messy), we use a smart approach:

1. **One main template** (`sentinel-rules.bicep`) - This is like a "rule factory" that creates multiple rules
2. **One reusable component** (`modules/scheduledRule.bicep`) - This is the "blueprint" for a single rule
3. **Environment files** (`env/deploy-*.bicep`) - These tell the factory what rules to make for each environment
4. **KQL files** (`kql/*.kql`) - These are your actual detection queries

## 🎯 Why This Approach?

✅ **Easy to add rules**: Just add one line to an array, not create new files  
✅ **Consistent**: All rules follow the same pattern  
✅ **Maintainable**: Change one thing, it applies to all rules  
✅ **Readable**: Your KQL queries are in separate files for easy review  
✅ **Scalable**: Works whether you have 5 rules or 500 rules  

## 📁 What's in Each File

```
infra/
├── sentinel-rules.bicep          # The "rule factory" - creates multiple rules
├── modules/
│   └── scheduledRule.bicep       # The "blueprint" for one rule
├── README.md                     # This file
env/
├── deploy-dev.bicep              # Dev environment rules list
├── deploy-prod.bicep             # Prod environment rules list
├── params/
│   ├── dev.jsonc                 # Dev workspace settings
│   └── prod.jsonc                # Prod workspace settings
kql/
├── uc-powershell-encoded.kql     # PowerShell detection query
├── suspicious-login-attempts.kql # Login attempts detection query
└── admin-account-anomaly.kql     # Admin account detection query
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

Tell Sentinel what entities to extract from your alerts:

```bicep
entities: {
  accountFullName: 'SubjectUserName'  // Extract Account entity
  hostName: 'Computer'                // Extract Host entity  
  ipAddress: 'IPAddress'              // Extract IP entity
}
```

## 📝 Custom Details

Add custom fields to your alerts:

```bicep
customDetails: {
  EncodedArgument: 'EncArg'           // Add custom field
  CommandLine: 'CommandLine'          // Add another custom field
}
```

## 🔄 Deployment

The GitHub Actions workflow automatically:
1. **Detects changes** in your code
2. **Validates** your Bicep files
3. **Deploys** to Dev automatically
4. **Waits for approval** before Prod

### Manual Deployment
```bash
# Deploy to Dev
az deployment group create \
  --resource-group sentinel-ws-dev \
  --template-file env/deploy-dev.bicep \
  --parameters env/params/dev.jsonc

# Preview what would be deployed
az deployment group what-if \
  --resource-group sentinel-ws-dev \
  --template-file env/deploy-dev.bicep \
  --parameters env/params/dev.jsonc
```

## 🌍 Environment Differences

- **Dev Environment**: 
  - Lower severity alerts
  - No incidents created
  - Focus on testing and validation

- **Prod Environment**:
  - Higher severity alerts  
  - Incidents created
  - Production-ready settings

Rules are configured differently in each environment file to match these needs.

## 🆘 Common Issues

### "Property doesn't exist" Error
Make sure all your rule objects have the same properties. If you don't need `grouping` or `customDetails`, use empty objects: `grouping: {}` and `customDetails: {}`

### KQL Column Errors
If you reference columns in `entities` or `customDetails`, make sure those columns are actually returned by your KQL query.

### Validation Errors
Run `az bicep build` locally first to catch syntax errors before deploying.

---

**Need help? Check the main README or create an issue! 🆘**
