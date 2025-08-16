# Sentinel Detection Rules Infrastructure

This directory contains the data-driven infrastructure for deploying Microsoft Sentinel detection rules.

## Architecture

### Data-Driven Design

Instead of individual Bicep files per rule, we use a scalable approach:

1. **Root Orchestrator** (`sentinel-rules.bicep`) - Loops through rules array
2. **Reusable Module** (`modules/scheduledRule.bicep`) - Single rule template with defaults
3. **Environment Wrappers** (`env/deploy-*.bicep`) - Load KQL and configure rules per environment
4. **KQL Files** (`kql/*.kql`) - Separate query files for better review
5. **Simple Params** (`env/params/*.jsonc`) - Just workspace names

### Benefits

✅ **Scalable**: Add rules by adding objects to arrays, not new templates  
✅ **DRY**: Sensible defaults in module, override only when needed  
✅ **Readable**: KQL lives in separate files for better review  
✅ **Maintainable**: One params file per environment, not per rule  
✅ **Consistent**: All rules follow the same pattern  

## File Structure

```
infra/
├── sentinel-rules.bicep          # Root orchestrator (loops through rules)
├── modules/
│   └── scheduledRule.bicep       # Reusable single rule module
├── README.md                     # This file
env/
├── deploy-dev.bicep              # Dev environment wrapper
├── deploy-prod.bicep             # Prod environment wrapper
├── params/
│   ├── dev.jsonc                 # Dev parameters (just workspace name)
│   └── prod.jsonc                # Prod parameters (just workspace name)
kql/
├── uc-powershell-encoded.kql     # PowerShell encoded command detection
├── suspicious-login-attempts.kql # Suspicious login attempts
└── admin-account-anomaly.kql     # Admin account anomaly detection
```

## Adding a New Rule

1. **Create KQL file** in `kql/` directory
2. **Add rule object** to the `rules` array in `env/deploy-dev.bicep` and `env/deploy-prod.bicep`
3. **Load KQL** using `loadTextContent('../kql/your-rule.kql')`
4. **Configure overrides** as needed (severity, tactics, entities, etc.)

### Example: Adding a New Rule

```bicep
// In env/deploy-dev.bicep
var kqlNewRule = loadTextContent('../kql/new-rule.kql')

var rules = [
  // ... existing rules ...
  {
    name: 'uc-new-rule'
    displayName: '[DEV] [ORG] – New Detection Rule'
    kql: kqlNewRule
    severity: 'Medium'
    enabled: true
    tactics: [ 'Execution' ]
    techniques: [ 'T1059' ]
    createIncident: true
    entities: {
      accountFullName: 'SubjectUserName'
      hostName: 'Computer'
    }
  }
]
```

## Module Parameters

The `scheduledRule.bicep` module accepts these parameters:

### Required
- `name` - Stable identifier for the rule
- `displayName` - Name shown in Sentinel portal
- `kql` - The detection query

### Optional (with defaults)
- `enabled` - Enable/disable rule (default: true)
- `severity` - Alert severity (default: 'Medium')
- `frequency` - Query frequency (default: 'PT1H')
- `period` - Query period (default: 'PT1H')
- `createIncident` - Create incidents (default: true)
- `tactics` - ATT&CK tactics array (default: [])
- `techniques` - ATT&CK techniques array (default: [])
- `grouping` - Grouping configuration object
- `entities` - Entity mappings object
- `customDetails` - Custom details object

## Entity Mapping

The module supports these entity types:

```bicep
entities: {
  accountFullName: 'SubjectUserName'  // Maps to Account entity
  hostName: 'Computer'                // Maps to Host entity
  ipAddress: 'IPAddress'              // Maps to IP entity
}
```

## Custom Details

Add custom fields to alerts:

```bicep
customDetails: {
  EncodedArgument: 'EncArg'           // Maps KQL column to alert field
  CommandLine: 'CommandLine'
}
```

## Deployment

The GitHub Actions workflow automatically detects changes and deploys:

```bash
# Manual deployment
az deployment group create \
  --resource-group sentinel-ws-dev \
  --template-file env/deploy-dev.bicep \
  --parameters env/params/dev.jsonc

# What-if preview
az deployment group what-if \
  --resource-group sentinel-ws-dev \
  --template-file env/deploy-dev.bicep \
  --parameters env/params/dev.jsonc
```

## Environment Differences

- **Dev**: Lower severity, no incidents, testing focus
- **Prod**: Higher severity, create incidents, production focus

Rules are configured differently per environment in the wrapper files.
