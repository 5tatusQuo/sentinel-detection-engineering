# Creating Your First Detection Rule

Welcome! This guide will walk you through creating your first Microsoft Sentinel detection rule using our beginner-friendly, data-driven approach.

## 🎯 What You'll Learn

- How to create a detection rule from scratch
- Understanding the new data-driven architecture
- How to write effective KQL queries
- How to test and deploy your rule safely

## 📋 Prerequisites

- Basic understanding of KQL (Kusto Query Language)
- Access to the repository
- Azure Sentinel workspace set up
- Azure CLI installed and logged in

## 🚀 Step-by-Step Guide

### Step 1: Plan Your Detection

Before you start coding, think about:
- **What are you trying to detect?** (e.g., suspicious logins, malware activity)
- **What data source will you use?** (e.g., SigninLogs, SecurityEvent, AuditLogs)
- **What's the threshold?** (e.g., 5 failed logins in 5 minutes)
- **What ATT&CK technique does this map to?** (e.g., T1078 for credential access)

### Step 2: Create Your KQL Query

Create a new file in the `kql/` directory:

```bash
# Create your KQL file
touch kql/my-first-detection.kql
```

Write your detection query. Here's a simple example for detecting multiple failed logins:

```kql
// kql/my-first-detection.kql
SigninLogs
| where TimeGenerated > ago(1h)
| where ResultType != 0  // Failed logins only
| summarize FailedCount = count(), 
          Applications = make_set(AppDisplayName), 
          Locations = make_set(Location), 
          TimeSpan = max(TimeGenerated) - min(TimeGenerated) 
    by IPAddress, bin(TimeGenerated, 5m)
| where FailedCount >= 5  // Alert if 5+ failed attempts
| where TimeSpan < 30m    // Within 30 minutes
| take 100
```

**Tips for writing good KQL:**
- Start simple and add complexity gradually
- Test your query in Sentinel Logs first
- Use `summarize` to group and count events
- Add time filters to avoid querying too much data
- Use `take` to limit results

### Step 3: Test Your KQL Query

1. **Go to your Sentinel workspace**
2. **Open Logs**
3. **Paste your KQL query**
4. **Click "Run"** to see if it works
5. **Check the results** - do they look right?

### Step 4: Configure Your Rule

#### 🚀 Super Easy Method (Recommended)

Use our automated rule creator:

```bash
# Run the interactive rule creator
pwsh scripts/new-rule.ps1
```

This will automatically:
- Create your KQL file
- Generate configurations for both dev and prod
- Set up entity mappings and custom details
- Save everything in the right places

#### 📝 Manual Method

If you prefer to do it manually:

**Step 4a: Add Your Rule to Dev Environment**

Open `env/rules/dev-rules.json` and add your rule to the `rules` array. This is **much easier** than editing Bicep files!

```json
{
  "name": "uc-my-first-detection",
  "displayName": "[DEV] [ORG] – My First Detection",
  "kqlFile": "my-first-detection.kql",
  "severity": "Medium",
  "enabled": true,
  "frequency": "PT1H",
  "period": "PT1H",
  "tactics": ["InitialAccess"],
  "techniques": ["T1078"],
  "createIncident": false,
  "grouping": {
    "enabled": true,
    "matchingMethod": "AllEntities"
  },
  "entities": {
    "ipAddress": "IPAddress"
  },
  "customDetails": {}
}
```

**Step 4b: Add Your Rule to Prod Environment**

Copy the same rule to `env/rules/prod-rules.json` but adjust for production:

```json
{
  "name": "uc-my-first-detection",
  "displayName": "[PROD] [ORG] – My First Detection",
  "kqlFile": "my-first-detection.kql",
  "severity": "High",
  "enabled": true,
  "frequency": "PT1H",
  "period": "PT1H",
  "tactics": ["InitialAccess"],
  "techniques": ["T1078"],
  "createIncident": true,
  "grouping": {
    "enabled": true,
    "matchingMethod": "AllEntities"
  },
  "entities": {
    "ipAddress": "IPAddress"
  },
  "customDetails": {}
}
```

**That's it!** No more complex Bicep editing! 🎉

### Step 5: Test Locally

Before you deploy, test that everything works:

```bash
# Test that your Bicep files are valid
az bicep build --file env/deploy-dev.bicep

# See what would be deployed (without actually deploying)
az deployment group what-if \
  --resource-group your-dev-resource-group \
  --template-file env/deploy-dev.bicep \
  --parameters env/params/dev.jsonc
```

### Step 6: Deploy Your Rule

1. **Create a Pull Request** with your changes
2. **The pipeline will automatically**:
   - Validate your Bicep files
   - Deploy to Dev environment
   - Run tests
3. **Wait for approval** before it goes to Prod

## 🎯 Understanding Each Part

### Rule Configuration

| Property | What it does | Example |
|----------|-------------|---------|
| `name` | Unique identifier | `"uc-my-detection"` |
| `displayName` | Name in Sentinel portal | `"[DEV] [ORG] – My Detection"` |
| `kqlFile` | Your KQL file name | `"my-detection.kql"` |
| `severity` | How serious is this? | `"Medium"`, `"High"`, `"Critical"` |
| `enabled` | Turn rule on/off | `true` or `false` |
| `frequency` | How often to run | `"PT1H"` (every hour) |
| `period` | How far back to look | `"PT1H"` (last hour) |

### ATT&CK Mapping

```bicep
tactics: [ 'InitialAccess', 'Execution' ]    // High-level tactics
techniques: [ 'T1078', 'T1059' ]             // Specific techniques
```

**Common ATT&CK Tactics:**
- `InitialAccess` - Getting into the network
- `Execution` - Running code
- `Persistence` - Staying in the network
- `PrivilegeEscalation` - Getting higher permissions
- `DefenseEvasion` - Avoiding detection

### Entity Mapping

Tell Sentinel what entities to extract from your alerts:

```bicep
entities: {
  accountFullName: 'SubjectUserName'  // Extract Account entity
  hostName: 'Computer'                // Extract Host entity
  ipAddress: 'IPAddress'              // Extract IP entity
}
```

### Custom Details

Add custom fields to your alerts:

```bicep
customDetails: {
  FailedAttempts: 'FailedCount'       // Add custom field
  Applications: 'Applications'        // Add another field
}
```

## 🧪 Testing Your Rule

### 1. Test the KQL Query
- Run it in Sentinel Logs
- Check the results make sense
- Verify it doesn't return too much data

### 2. Test the Bicep Template
```bash
az bicep build --file env/deploy-dev.bicep
```

### 3. Test the Deployment
```bash
az deployment group what-if \
  --resource-group your-dev-rg \
  --template-file env/deploy-dev.bicep \
  --parameters env/params/dev.jsonc
```

### 4. Monitor Your Rule
- Check that it's enabled in Sentinel
- Look for alerts being generated
- Verify the severity and details are correct

## 🆘 Common Issues and Solutions

### "Property doesn't exist" Error
**Problem**: Missing properties in your rule object
**Solution**: Make sure all rule objects have `grouping: {}` and `customDetails: {}`

### KQL Column Errors
**Problem**: Referencing columns that don't exist in your query
**Solution**: Check that your KQL actually returns the columns you're referencing

### No Alerts Generated
**Problem**: Rule is running but not finding anything
**Solution**: 
- Check your KQL query returns results in Sentinel Logs
- Verify your data sources are enabled
- Check the time range and frequency settings

### Too Many Alerts
**Problem**: Rule is generating too many alerts
**Solution**:
- Increase your threshold (e.g., from 5 to 10 failed attempts)
- Add more specific filters to your KQL
- Adjust the time window

## 📚 Next Steps

Once you've created your first rule:

1. **Learn more KQL**: Practice writing different types of queries
2. **Explore ATT&CK**: Map your detections to specific techniques
3. **Add entity mapping**: Extract useful entities from your alerts
4. **Create custom details**: Add relevant fields to your alerts
5. **Optimize performance**: Make your queries more efficient

## 🎓 Learning Resources

- **[KQL Query Language](https://docs.microsoft.com/en-us/azure/data-explorer/kusto/query/)**
- **[MITRE ATT&CK Framework](https://attack.mitre.org/)**
- **[Microsoft Sentinel Documentation](https://docs.microsoft.com/en-us/azure/sentinel/)**
- **[Bicep Templates](https://docs.microsoft.com/en-us/azure/azure-resource-manager/bicep/)**

---

**Congratulations! You've created your first detection rule! 🎉**

Need help? Check the main README or create an issue in the repository.
