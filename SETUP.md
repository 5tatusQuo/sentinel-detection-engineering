# Repository Setup Guide

This guide contains all the TODOs and configuration steps needed to complete the Microsoft Sentinel detection engineering repository setup.

## 🔧 Required Configuration

### 1. Organization Prefix
Replace `[ORG]` with your organization prefix throughout the repository:

**Files to update:**
- `README.md`
- `organizations/*/env/deploy-dev.bicep`
- `organizations/*/env/deploy-prod.bicep`
- All documentation files

**Example:** Replace `[ORG]` with `UBH`, `ACME`, `CORP`, etc.

### 2. Azure Configuration

#### Required Azure Resources
- [ ] Azure subscription with Microsoft Sentinel enabled
- [ ] Dev Log Analytics workspace
- [ ] Prod Log Analytics workspace
- [ ] Resource groups for each workspace
- [ ] OIDC application for GitHub → Azure authentication

#### Azure Secrets to Set
Set these secrets in your GitHub repository:

```
AZURE_TENANT_ID=your-tenant-id
AZURE_SUBSCRIPTION_ID=your-subscription-id
AZURE_CLIENT_ID=your-oidc-app-client-id
SENTINEL_RG_DEV=your-dev-resource-group
SENTINEL_WS_DEV=your-dev-workspace-name
SENTINEL_RG_PROD=your-prod-resource-group
SENTINEL_WS_PROD=your-prod-workspace-name
```

### 3. GitHub Environment Setup

#### Create `sentinel-prod` Environment
1. Go to Repository Settings → Environments
2. Create new environment: `sentinel-prod`
3. Add required reviewers (Detection Engineering team)
4. Configure protection rules:
   - Require pull request reviews
   - Require status checks to pass
   - Restrict pushes to matching branches

#### Required Reviewers
Add these users as required reviewers:
- [ ] Security team lead
- [ ] Detection engineering team members
- [ ] Platform team representative

### 4. Azure Authentication Setup for GitHub Actions

#### Option 1: Service Principal with Federated Identity Credential (Recommended)

This approach creates a service principal with federated identity credentials for secure OIDC authentication.

##### Step 1: Create Service Principal
```bash
# Create service principal with contributor role
az ad sp create-for-rbac \
  --name "GitHubActions-SentinelDetection" \
  --role contributor \
  --scopes /subscriptions/YOUR_SUBSCRIPTION_ID
```

##### Step 2: Get Service Principal Object ID
```bash
# Get the service principal object ID
SP_OBJECT_ID=$(az ad sp list --display-name "GitHubActions-SentinelDetection" --query "[].id" -o tsv)
echo "Service Principal Object ID: $SP_OBJECT_ID"
```

##### Step 3: Get Application Object ID
```bash
# Get the application object ID (needed for federated credential)
APP_OBJECT_ID=$(az ad app list --display-name "GitHubActions-SentinelDetection" --query "[].id" -o tsv)
echo "Application Object ID: $APP_OBJECT_ID"
```

##### Step 4: Create Federated Identity Credential
```bash
# Create federated identity credential for GitHub Actions
az ad app federated-credential create \
  --id $APP_OBJECT_ID \
  --parameters "{\"name\":\"github-actions\",\"issuer\":\"https://token.actions.githubusercontent.com\",\"subject\":\"repo:YOUR_ORG/YOUR_REPO:ref:refs/heads/main\",\"audiences\":[\"api://AzureADTokenExchange\"]}"

# Replace YOUR_ORG/YOUR_REPO with your actual repository (e.g., 5tatusQuo/sentinel-detection-engineering)
```

##### Step 5: Get Required Values for GitHub Secrets
```bash
# Get tenant ID
TENANT_ID=$(az account show --query tenantId -o tsv)
echo "Tenant ID: $TENANT_ID"

# Get subscription ID
SUBSCRIPTION_ID=$(az account show --query id -o tsv)
echo "Subscription ID: $SUBSCRIPTION_ID"

# Get client ID (application ID)
CLIENT_ID=$(az ad app list --display-name "GitHubActions-SentinelDetection" --query "[].appId" -o tsv)
echo "Client ID: $CLIENT_ID"
```

#### Option 2: Service Principal with Client Secret (Alternative)

If OIDC is not available, use a service principal with client secret:

```bash
# Create service principal with secret
az ad sp create-for-rbac \
  --name "GitHubActions-SentinelDetection" \
  --role contributor \
  --scopes /subscriptions/YOUR_SUBSCRIPTION_ID \
  --sdk-auth
```

**Note**: Store the output securely and add to GitHub secrets.

### 5. Workspace Configuration

#### Update Configuration Files
Update workspace names and organization settings in your configuration files:

**`config/organizations.json`:**
```json
{
  "organizations": [
    {
      "name": "org1",
      "displayName": "Organization 1",
      "environments": {
        "dev": {
          "resourceGroup": "your-dev-resource-group",
          "workspaceName": "your-dev-workspace-name"
        },
        "prod": {
          "resourceGroup": "your-prod-resource-group", 
          "workspaceName": "your-prod-workspace-name"
        }
      }
    }
  ]
}
```

## 🚀 Initial Deployment

### 1. Test Bicep Templates
```bash
# Test the main templates
az bicep build --file infra/sentinel-rules.bicep
az bicep build --file infra/modules/scheduledRule.bicep

# Test organization-specific templates
az bicep build --file organizations/org1/env/deploy-dev.bicep
az bicep build --file organizations/org1/env/deploy-prod.bicep
```

### 2. Validate Deployment
```bash
# What-if deployment for Dev (using script)
pwsh -File scripts/deploy-organizations.ps1 -Environment dev -WhatIf

# What-if deployment for Prod (using script)
pwsh -File scripts/deploy-organizations.ps1 -Environment prod -WhatIf
```

### 3. Manual First Deployment
```bash
# Deploy to Dev
pwsh -File scripts/deploy-organizations.ps1 -Environment dev

# Deploy to Prod (after approval)
pwsh -File scripts/deploy-organizations.ps1 -Environment prod
```

## 📋 Pre-Deployment Checklist

### Repository Setup
- [ ] Organization prefix updated throughout
- [ ] Azure secrets configured in GitHub
- [ ] GitHub environment `sentinel-prod` created
- [ ] Required reviewers added
- [ ] OIDC authentication configured
- [ ] Azure resources created and accessible

### Testing
- [ ] Bicep templates build successfully
- [ ] What-if deployment works
- [ ] PowerShell scripts run without errors
- [ ] GitHub Actions workflows validate
- [ ] Dev workspace accessible

### Security
- [ ] Azure permissions configured correctly
- [ ] GitHub environment protection enabled
- [ ] OIDC authentication working
- [ ] Secrets properly secured

## 🔄 Workflow Testing

### Test Vendor Sync
```bash
# Manual trigger
gh workflow run vendor-sync.yml -f workspace=dev
```

### Test Drift Detection & Sync
```bash
# Manual trigger
gh workflow run drift-check.yml -f environment=dev -f organization=org1
```

### Test Deployment
1. Create a test PR with rule changes
2. Verify validation passes
3. Merge to main
4. Monitor Dev deployment
5. Approve Prod deployment

## 📚 Documentation Updates

### Customize Documentation
Update these files with your organization's specifics:
- [ ] `README.md` - Organization details
- [ ] `docs/pipeline-summary.md` - Team contacts
- [ ] `docs/approvals.md` - Reviewer names
- [ ] `docs/naming-and-metadata.md` - Organization standards

### Add Organization-Specific Content
- [ ] Team contact information
- [ ] Escalation procedures
- [ ] Custom naming conventions
- [ ] Specific security requirements

## 🛠️ Troubleshooting

### Common Issues

#### Azure Authentication Issues

**Common Error**: `AADSTS700016: Application with identifier '***' was not found in the directory`

**Solution**: This occurs when the federated identity credential is not properly configured. Follow these steps:

```bash
# 1. Verify service principal exists
az ad sp list --display-name "GitHubActions-SentinelDetection"

# 2. Check if federated credential exists
APP_OBJECT_ID=$(az ad app list --display-name "GitHubActions-SentinelDetection" --query "[].id" -o tsv)
az ad app federated-credential list --id $APP_OBJECT_ID

# 3. If federated credential is missing, recreate it
az ad app federated-credential create \
  --id $APP_OBJECT_ID \
  --parameters "{\"name\":\"github-actions\",\"issuer\":\"https://token.actions.githubusercontent.com\",\"subject\":\"repo:YOUR_ORG/YOUR_REPO:ref:refs/heads/main\",\"audiences\":[\"api://AzureADTokenExchange\"]}"
```

**Common Error**: `Get-AzAccessToken: The term 'Get-AzAccessToken' is not recognized`

**Solution**: The PowerShell script needs to use Azure CLI instead of Azure PowerShell:

```powershell
# Instead of Get-AzAccessToken, use:
$tokenResponse = az account get-access-token --resource "https://management.azure.com" | ConvertFrom-Json
$token = $tokenResponse.accessToken
```

**Common Error**: `Permission to repository denied to github-actions[bot]`

**Solution**: Update workflow permissions and use proper git authentication:

```yaml
permissions:
  id-token: write
  contents: write
  pull-requests: write
```

**Test Azure CLI authentication**:
```bash
az login
az account show
az account get-access-token --resource "https://management.azure.com"
```

#### Bicep Build Issues
```bash
# Update Bicep CLI
az bicep upgrade

# Validate templates
az bicep build --file infra/sentinel-rules.bicep
pwsh -File scripts/validate-bicep.ps1
```

#### PowerShell Script Issues
```powershell
# Test PowerShell execution
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

# Test Azure CLI
az login
az account show
```

## 📞 Support

### Internal Contacts
- **Detection Engineering Team**: Primary support
- **Azure Platform Team**: Infrastructure issues
- **Security Operations**: Rule effectiveness

### External Resources
- [Microsoft Sentinel Documentation](https://docs.microsoft.com/en-us/azure/sentinel/)
- [Bicep Documentation](https://docs.microsoft.com/en-us/azure/azure-resource-manager/bicep/)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)

## ✅ Completion Checklist

- [ ] Organization prefix updated
- [ ] Azure resources created
- [ ] GitHub secrets configured
- [ ] Environment protection enabled
- [ ] OIDC authentication working
- [ ] First deployment successful
- [ ] Workflows tested
- [ ] Documentation customized
- [ ] Team trained on process
- [ ] Monitoring configured

## 🎯 Next Steps

1. **Add Your First Custom Rule (Portal-First Approach)**
   - Create and test your rule directly in the Azure Sentinel portal
   - Use the dev environment for initial testing and refinement
   - Once satisfied, the Drift Detection & Sync workflow will automatically detect and sync the rule back to the repository
   - Review and merge the auto-generated pull request to deploy to production

2. **Configure Monitoring**
   - Set up alerting for deployment failures
   - Monitor drift detection results
   - Track rule effectiveness

3. **Team Training**
   - Review approval process with focus on portal-first approach
   - Train on drift detection and sync workflow
   - Establish review guidelines for auto-generated PRs

4. **Continuous Improvement**
   - Regular process reviews
   - Performance optimization
   - Security enhancements
