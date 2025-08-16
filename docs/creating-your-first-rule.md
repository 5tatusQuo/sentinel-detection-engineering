# Creating Your First Detection Rule

This guide will walk you through creating your first Microsoft Sentinel detection rule using our beginner-friendly template.

## 🎯 What You'll Learn

- How to create a detection rule from scratch
- Understanding each part of the Bicep template
- How to customize the rule for your environment
- How to test and deploy your rule

## 📋 Prerequisites

- Basic understanding of KQL (Kusto Query Language)
- Access to the repository
- Azure Sentinel workspace set up

## 🚀 Step-by-Step Guide

### Step 1: Copy the Template

1. **Find the template**: Look at `rules/custom/suspicious-login-attempts.bicep`
2. **Copy it**: Create a new file with your rule name
3. **Rename it**: Use a descriptive name like `my-first-rule.bicep`

### Step 2: Understand the Structure

The template is divided into 7 clear sections:

```
1. METADATA     - Information about the rule
2. PARAMETERS   - Values you can change
3. DETECTION QUERY - The KQL query that finds threats
4. ATTACK FRAMEWORK - MITRE ATT&CK mapping
5. INCIDENT SETTINGS - How to handle alerts
6. THE ACTUAL RULE - Putting it all together
7. OUTPUTS - Information returned after deployment
```

### Step 3: Customize Your Rule

#### A. Change the Rule Name
```bicep
param ruleDisplayName string = '[ORG] – My First Detection Rule (T1234)'
```

#### B. Set the Severity
```bicep
param ruleSeverity string = 'Medium'  // Critical, High, Medium, Low, Informational
```

#### C. Write Your Detection Query
This is the most important part! Here's a simple example:

```kql
// Look for suspicious activity
SigninLogs
| where ResultType == "50126"  // Failed login
| where TimeGenerated >= ago(1h)  // Last hour
| summarize FailedAttempts = count() by IPAddress
| where FailedAttempts >= 5  // Alert if 5+ failed attempts
```

#### D. Map to ATT&CK Framework
```bicep
param attackTactics array = [
  'Initial Access'    // What tactic does this detect?
]

param attackTechniques array = [
  'T1078'  // What specific technique?
]
```

### Step 4: Test Your Rule

#### A. Build the Template
```bash
az bicep build --file rules/custom/my-first-rule.bicep
```

#### B. Test the Query
1. Go to your Sentinel workspace
2. Open Logs
3. Paste your KQL query
4. Click "Run" to see if it works

#### C. What-if Deployment
```bash
az deployment group what-if \
  --resource-group YOUR_RG \
  --template-file rules/custom/my-first-rule.bicep \
  --parameters rules/custom/params/dev.jsonc
```

### Step 5: Add Parameters

Add your rule's parameters to the environment files:

#### Dev Environment (`rules/custom/params/dev.jsonc`)
```json
{
  "parameters": {
    "ruleDisplayName": {
      "value": "[ORG] – My First Rule [DEV]"
    },
    "ruleSeverity": {
      "value": "Low"
    },
    "ruleEnabled": {
      "value": true
    }
  }
}
```

#### Prod Environment (`rules/custom/params/prod.jsonc`)
```json
{
  "parameters": {
    "ruleDisplayName": {
      "value": "[ORG] – My First Rule"
    },
    "ruleSeverity": {
      "value": "Medium"
    },
    "ruleEnabled": {
      "value": true
    }
  }
}
```

### Step 6: Deploy Your Rule

1. **Create a Pull Request**
   ```bash
   git add rules/custom/my-first-rule.bicep
   git add rules/custom/params/dev.jsonc
   git add rules/custom/params/prod.jsonc
   git commit -m "feat: add my first detection rule"
   git push origin my-feature-branch
   ```

2. **Review and Merge**
   - The pipeline will automatically deploy to Dev
   - You'll need approval for Prod deployment

## 🔍 Common Patterns

### Pattern 1: Count-based Detection
```kql
// Count events and alert if threshold exceeded
YourTable
| where TimeGenerated >= ago(1h)
| summarize EventCount = count() by Field1, Field2
| where EventCount >= 10
```

### Pattern 2: Time-based Detection
```kql
// Alert if events happen too quickly
YourTable
| where TimeGenerated >= ago(1h)
| summarize TimeSpan = max(TimeGenerated) - min(TimeGenerated) by Field1
| where TimeSpan < 5m  // Less than 5 minutes
```

### Pattern 3: Anomaly Detection
```kql
// Alert if activity is unusual
YourTable
| where TimeGenerated >= ago(24h)
| summarize ActivityCount = count() by bin(TimeGenerated, 1h)
| where ActivityCount > 100  // More than usual
```

## 🛠️ Best Practices

### 1. Start Simple
- Begin with basic queries
- Test thoroughly before adding complexity
- Use the Dev environment for testing

### 2. Use Clear Names
- Rule names should describe what they detect
- Include the ATT&CK technique ID
- Use consistent naming conventions

### 3. Document Your Work
- Add comments to your KQL queries
- Explain why you chose certain thresholds
- Document any assumptions

### 4. Test Thoroughly
- Test with real data when possible
- Check for false positives
- Verify the query performance

### 5. Use Parameters
- Make thresholds configurable
- Allow different settings per environment
- Use parameters for values that might change

## 🚨 Troubleshooting

### Common Issues

1. **Query Syntax Errors**
   - Check KQL syntax in Sentinel Logs first
   - Use the query validator in the portal

2. **No Results**
   - Verify your data source is connected
   - Check the time range
   - Ensure the table exists

3. **Too Many False Positives**
   - Adjust your thresholds
   - Add more specific filters
   - Test with historical data

4. **Performance Issues**
   - Add time filters
   - Use efficient operators
   - Consider query frequency

## 📚 Next Steps

1. **Learn KQL**: Practice writing queries in Sentinel Logs
2. **Study ATT&CK**: Understand the threat framework
3. **Review Existing Rules**: Look at vendor rules for inspiration
4. **Join the Community**: Connect with other detection engineers

## 🆘 Getting Help

- **Documentation**: Check the `docs/` folder
- **Team**: Ask your Detection Engineering team
- **GitHub**: Create an issue in this repository
- **Microsoft Docs**: [Sentinel Documentation](https://docs.microsoft.com/en-us/azure/sentinel/)

## 🎉 Congratulations!

You've created your first detection rule! Remember:
- Start simple and iterate
- Test everything thoroughly
- Ask for help when needed
- Keep learning and improving

Happy hunting! 🕵️‍♂️
