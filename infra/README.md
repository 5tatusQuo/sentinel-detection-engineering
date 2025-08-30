# Sentinel Detection Rules Infrastructure

This directory contains the Bicep templates that deploy Microsoft Sentinel detection rules across multiple organizations.

## 🏗️ How It Works

Instead of managing individual rule files, we use a scalable template approach:

1. **Main Template** (`sentinel-rules.bicep`) - Rule factory that creates multiple rules
2. **Rule Module** (`modules/scheduledRule.bicep`) - Blueprint for individual rules
3. **Organization Files** (`organizations/orgX/env/deploy-*.bicep`) - Specify which rules to deploy
4. **KQL Files** (`organizations/orgX/kql/`) - Actual detection queries

## 📁 File Structure

```
infra/
├── sentinel-rules.bicep          # Main template (rule factory)
└── modules/
    └── scheduledRule.bicep       # Individual rule blueprint

organizations/orgX/
├── env/
│   ├── deploy-dev.bicep          # Dev environment rules
│   └── deploy-prod.bicep         # Prod environment rules
└── kql/
    ├── dev/*.kql                 # Dev KQL queries
    └── prod/*.kql                # Prod KQL queries
```

## 🚀 How Rules Are Added

**Portal-First Approach (Recommended)**

1. **Create in Azure Sentinel Portal** - Use the GUI to create and test your rule
2. **Run Drift Detection & Sync** - Use the GitHub Actions workflow to sync changes back
3. **Review & Merge PR** - The workflow creates a PR with the generated files
4. **Auto-Deploy** - Merging deploys to production automatically

**⚠️ Manual Creation Not Recommended**

Manual file creation is error-prone and bypasses testing. The portal-first approach ensures rules work correctly before deployment.

## ⚙️ Rule Configuration

### Required Properties
- `name` - Unique identifier
- `displayName` - Display name in Sentinel
- `kql` - Detection query

### Optional Properties (with defaults)
- `enabled: true` - Enable/disable rule
- `severity: 'Medium'` - Alert severity
- `frequency: 'PT1H'` - How often to run
- `period: 'PT1H'` - Lookback period
- `createIncident: true` - Create incidents
- `tactics: []` - MITRE ATT&CK tactics
- `techniques: []` - MITRE ATT&CK techniques

## 🔗 Entity Mapping

Extract entities from your detections:

```bicep
// Simple format (auto-converted)
entities: {
  accountFullName: 'UserName'
  hostName: 'Computer'
}

// Azure format (recommended)
entities: {
  entityType: 'Account'
  fieldMappings: [{
    identifier: 'FullName'
    columnName: 'UserName'
  }]
}
```

## 🌍 Environment Differences

### Dev Environment
- Lower severity alerts
- `createIncident: false` (testing only)
- `[DEV]` prefix in display names

### Prod Environment  
- Production severity levels
- `createIncident: true` (creates incidents)
- `[PROD]` prefix in display names

## 🔄 Deployment Process

1. **Validation** - Bicep templates validated automatically
2. **Dev Deployment** - Feature branches deploy to dev environment
3. **Prod Deployment** - Main branch deploys to production (with approval)

## 🛠️ Local Testing

```bash
# Validate Bicep templates
pwsh -File scripts/validate-bicep.ps1

# Build specific template
az bicep build --file organizations/org1/env/deploy-dev.bicep

# Test deployment (what-if)
az deployment group what-if \
  --resource-group your-dev-rg \
  --template-file organizations/org1/env/deploy-dev.bicep
```

## 🚨 Common Issues

### Template Compilation Errors
- Ensure all rule objects have consistent properties
- Use empty objects for optional fields: `customDetails: {}`
- Verify KQL files exist and are referenced correctly

### Entity Mapping Errors
- Column names in mappings must exist in KQL query output
- Test queries in Sentinel Logs before deployment

### Deployment Failures
- Check Azure permissions (Contributor on resource group)
- Verify workspace and resource group names
- Review ARM deployment logs in Azure portal

---

For detailed guides, see the main [documentation](../docs/).