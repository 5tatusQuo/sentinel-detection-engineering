# 📋 Rule Configuration Files

This directory contains simple JSON files that define which rules are deployed to each environment. This makes it **super easy** to add new rules without touching any Bicep code!

## 🎯 How to Add a New Rule

### 🚀 Super Easy Method (Recommended)

Use our automated rule creator:

```bash
# Run the interactive rule creator
pwsh scripts/new-rule.ps1
```

This will:
1. **Ask you for rule details** (name, severity, tactics, etc.)
2. **Create your KQL file** automatically
3. **Generate Bicep code** that you can copy-paste into deployment files
4. **Provide step-by-step instructions** for adding to your Bicep files

### 📝 Manual Method

If you prefer to do it manually:

#### Step 1: Create Your KQL File
First, create your KQL query in the `kql/` directory:
```bash
# Create your KQL file
touch kql/my-new-detection.kql
```

#### Step 2: Generate Bicep Configuration
Use our generator script:
```bash
pwsh scripts/generate-rule-config.ps1 -KqlFile "kql/my-new-detection.kql" -RuleName "my-new-detection" -Severity "Medium" -Environment "dev" -Tactics "InitialAccess" -Techniques "T1078"
```

#### Step 3: Add to Bicep Files
Copy the generated Bicep code to your deployment files:

**For Dev (`env/deploy-dev.bicep`):**
```bicep
// Add this KQL loading line:
var kqlMyNewDetection = loadTextContent('../kql/my-new-detection.kql')

// Add this rule object to the rules array:
{
  name: 'my-new-detection'
  displayName: '[DEV] [ORG] – My New Detection'
  kql: kqlMyNewDetection
  severity: 'Medium'
  enabled: true
  frequency: 'PT1H'
  period: 'PT1H'
  tactics: [ 'InitialAccess' ]
  techniques: [ 'T1078' ]
  createIncident: false
  grouping: {
    enabled: true
    matchingMethod: 'AllEntities'
  }
  entities: {
    accountFullName: 'SubjectUserName'
  }
  customDetails: {}
}
```

**For Prod (`env/deploy-prod.bicep`):**
```bicep
// Add this KQL loading line:
var kqlMyNewDetection = loadTextContent('../kql/my-new-detection.kql')

// Add this rule object to the rules array:
{
  name: 'my-new-detection'
  displayName: '[PROD] [ORG] – My New Detection'
  kql: kqlMyNewDetection
  severity: 'High'
  enabled: true
  frequency: 'PT1H'
  period: 'PT1H'
  tactics: [ 'InitialAccess' ]
  techniques: [ 'T1078' ]
  createIncident: true
  grouping: {
    enabled: true
    matchingMethod: 'AllEntities'
  }
  entities: {
    accountFullName: 'SubjectUserName'
  }
  customDetails: {}
}
```

### Step 4: Deploy!
Commit your changes and the automated pipeline will deploy your new rule!

## 📝 Configuration Options

### Required Fields
- **`name`**: Unique identifier for the rule (no spaces, use hyphens)
- **`displayName`**: What users see in Sentinel (include [ENV] and [ORG])
- **`kqlFile`**: Name of your KQL file in the `kql/` directory
- **`severity`**: `Low`, `Medium`, `High`, or `Critical`
- **`enabled`**: `true` or `false`
- **`frequency`**: How often to run (e.g., `PT1H` = every hour)
- **`period`**: Time window to analyze (e.g., `PT1H` = last hour)
- **`tactics`**: Array of MITRE ATT&CK tactics
- **`techniques`**: Array of MITRE ATT&CK techniques
- **`createIncident`**: `true` to create incidents, `false` for alerts only

### Optional Fields
- **`grouping`**: How to group related alerts
- **`entities`**: Map KQL columns to Sentinel entities
- **`customDetails`**: Add custom fields to alerts

## 🔧 Common Configurations

### Simple Alert (No Incident)
```json
{
  "createIncident": false,
  "grouping": {
    "enabled": true,
    "matchingMethod": "AllEntities"
  }
}
```

### Create Incidents
```json
{
  "createIncident": true,
  "grouping": {
    "enabled": true,
    "matchingMethod": "AllEntities"
  }
}
```

### Map Entities
```json
{
  "entities": {
    "accountFullName": "SubjectUserName",
    "hostName": "Computer",
    "ipAddress": "IPAddress"
  }
}
```

### Add Custom Details
```json
{
  "customDetails": {
    "CommandLine": "CommandLine",
    "ProcessName": "ProcessName"
  }
}
```

## 🎨 Copy-Paste Template

Use `template-new-rule.json` as a starting point:

```bash
# Copy the template
cp template-new-rule.json my-new-rule.json

# Edit it with your details
# Then copy the content into dev-rules.json and prod-rules.json
```

## ✅ Best Practices

1. **Test in Dev First**: Always add to `dev-rules.json` first
2. **Use Descriptive Names**: Make rule names clear and meaningful
3. **Include [ENV] and [ORG]**: Always in display names
4. **Set Appropriate Severity**: Dev = Lower, Prod = Higher
5. **Enable Incidents in Prod**: Usually `createIncident: true` for production
6. **Map Relevant Entities**: Help with incident correlation
7. **Add Custom Details**: Include useful fields from your KQL

## 🚀 That's It!

No more complex Bicep editing! Just add your rule to the JSON files and commit. The automation handles the rest! 🎉
