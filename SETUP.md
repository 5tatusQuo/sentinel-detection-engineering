# Repository Setup Guide

This guide contains all the TODOs and configuration steps needed to complete the Microsoft Sentinel detection engineering repository setup.

## 🔧 Required Configuration

### 1. Organization Prefix
Replace `[ORG]` with your organization prefix throughout the repository:

**Files to update:**
- `README.md`
- `rules/custom/uc-powershell-encoded.bicep`
- `rules/custom/params/dev.jsonc`
- `rules/custom/params/prod.jsonc`
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

### 4. OIDC Setup for Azure Authentication

#### Create OIDC Application
```bash
# Create OIDC application
az ad app create --display-name "GitHub-Sentinel-Deploy"

# Get the client ID
az ad app list --display-name "GitHub-Sentinel-Deploy" --query "[].appId" -o tsv

# Create service principal
az ad sp create --id <client-id>

# Assign roles
az role assignment create \
  --assignee <client-id> \
  --role "Contributor" \
  --scope "/subscriptions/<subscription-id>/resourceGroups/<resource-group>"
```

#### Configure GitHub OIDC
Add this to your repository settings:
- **Audience**: `api://AzureADTokenExchange`
- **Issuer**: `https://token.actions.githubusercontent.com`

## 🚀 Initial Deployment

### 1. First-Time Setup
```bash
# Clone the repository
git clone <your-repo-url>
cd <repo-name>

# Test Bicep templates
az bicep build --file rules/custom/uc-powershell-encoded.bicep

# Test what-if deployment (Dev)
az deployment group what-if \
  --resource-group $SENTINEL_RG_DEV \
  --template-file rules/custom/uc-powershell-encoded.bicep \
  --parameters rules/custom/params/dev.jsonc
```

### 2. Manual First Deployment
```bash
# Deploy to Dev
az deployment group create \
  --resource-group $SENTINEL_RG_DEV \
  --template-file rules/custom/uc-powershell-encoded.bicep \
  --parameters rules/custom/params/dev.jsonc

# Deploy to Prod (after approval)
az deployment group create \
  --resource-group $SENTINEL_RG_PROD \
  --template-file rules/custom/uc-powershell-encoded.bicep \
  --parameters rules/custom/params/prod.jsonc
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

### Test Drift Detection
```bash
# Manual trigger
gh workflow run drift-check.yml -f workspace=dev
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

#### Azure Authentication
```bash
# Test Azure CLI authentication
az login
az account show

# Test OIDC
az account get-access-token --resource https://management.azure.com
```

#### Bicep Build Issues
```bash
# Update Bicep CLI
az bicep upgrade

# Validate template
az bicep build --file rules/custom/uc-powershell-encoded.bicep
```

#### PowerShell Script Issues
```powershell
# Test PowerShell execution
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

# Test Azure PowerShell
Connect-AzAccount
Get-AzAccessToken -ResourceUrl "https://management.azure.com"
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

1. **Add Your First Custom Rule**
   - Create new Bicep template
   - Add parameters to environment files
   - Test in Dev environment
   - Deploy to production

2. **Configure Monitoring**
   - Set up alerting for deployment failures
   - Monitor drift detection results
   - Track rule effectiveness

3. **Team Training**
   - Review approval process
   - Train on Bicep development
   - Establish review guidelines

4. **Continuous Improvement**
   - Regular process reviews
   - Performance optimization
   - Security enhancements
