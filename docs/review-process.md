# Sentinel Detection Rule Review Process

## Overview

This document outlines the streamlined review process for Azure Sentinel detection rules using our automated sync workflows. The process is designed to leverage the ease of the Azure Sentinel portal while maintaining version control and automated deployment.

## Workflow Types

### 1. Automatic Nightly Sync (Production Only)
- **Trigger**: Runs automatically every night at 2 AM UTC
- **Environment**: Production only
- **Scope**: Both custom and vendor rules
- **Branch**: Direct commits to `main`
- **Purpose**: Keep repository in sync with production changes

### 2. Manual Sync (Development & Production)
- **Trigger**: Manual workflow dispatch
- **Environment**: Both DEV and PROD
- **Scope**: Custom rules only (vendor rules optional)
- **Branch**: Creates feature branches for review
- **Purpose**: Sync changes made in portal back to repository for review

## Rule Creation Process

### New Rules
1. **Create in Azure Sentinel Portal** (DEV environment recommended)
2. **Run Manual Sync Workflow**:
   - Go to Actions → Manual Sync from Sentinel
   - Select environment (DEV)
   - Enable "Create new feature branch for review"
   - Run workflow
3. **Review Generated PR**:
   - Review KQL queries and rule configurations
   - Test in DEV environment
   - Approve and merge to main
4. **Automatic Deployment**:
   - Merging to main triggers production deployment
   - Rules are automatically deployed to PROD with escalated severity

### Editing Existing Rules
1. **Make Changes in Azure Sentinel Portal** (DEV environment)
2. **Run Manual Sync Workflow**:
   - Go to Actions → Manual Sync from Sentinel
   - Select environment (DEV)
   - Disable "Create new feature branch for review" (uses existing branch)
   - Run workflow
3. **Review Changes**:
   - Review synced changes in existing branch
   - Test modifications
   - Commit and push changes
4. **Deploy to Production**:
   - Merge to main triggers production deployment

## Manual Sync Workflow Usage

### For New Rules
```bash
# Workflow inputs:
Environment: dev
Create new feature branch for review: true
Include vendor rules: false
Force sync: false
```

### For Existing Rule Edits
```bash
# Workflow inputs:
Environment: dev
Branch name: feature/rule-name (existing branch)
Create new feature branch for review: false
Include vendor rules: false
Force sync: false
```

### For Production Sync
```bash
# Workflow inputs:
Environment: prod
Create new feature branch for review: true
Include vendor rules: true
Force sync: false
```

## Sync Script Details

The `scripts/sync-sentinel-changes.ps1` script handles the automated synchronization:

### Key Features
- **Environment-aware**: Automatically adjusts severity and incident creation for PROD
- **Vendor rule filtering**: Can include/exclude vendor rules
- **Branch management**: Supports creating new branches or updating existing ones
- **Dry run mode**: Preview changes before applying
- **Force sync**: Override change detection

### Parameters
- `ResourceGroup`: Azure resource group name
- `WorkspaceName`: Sentinel workspace name
- `Environment`: "dev" or "prod" (affects rule configuration)
- `IncludeVendorRules`: Include vendor rules in sync
- `CreateBranch`: Create new feature branch
- `ForceSync`: Force sync even if no changes detected
- `DryRun`: Preview changes without applying

### Environment-Specific Behavior
- **DEV**: Uses original severity, configurable incident creation
- **PROD**: Escalates severity (Low→Medium, Medium→High, High→Critical), always creates incidents

## Best Practices

### For Reviewers
1. **Use DEV Environment**: Make changes in DEV environment for easier testing
2. **Test Before Sync**: Verify rule behavior in portal before syncing
3. **Review KQL**: Check query syntax and performance
4. **Validate Configuration**: Ensure entity mappings and custom details are correct
5. **Use Dry Run**: Preview changes before applying sync

### For Authors
1. **Create in Portal**: Use Azure Sentinel portal for initial rule creation
2. **Sync Regularly**: Run manual sync after making portal changes
3. **Review Generated Code**: Verify synced KQL and Bicep configurations
4. **Test in DEV**: Ensure rules work correctly before production deployment

### For Administrators
1. **Monitor Nightly Sync**: Check nightly sync logs for any issues
2. **Review Production Changes**: Monitor automatic production deployments
3. **Backup Vendor Rules**: Use manual sync with vendor rules enabled for backups
4. **Audit Trail**: All changes are tracked in git history

## Troubleshooting

### Common Issues
1. **No Changes Detected**: Use `ForceSync` parameter to override
2. **Vendor Rules Missing**: Enable `IncludeVendorRules` parameter
3. **Branch Conflicts**: Resolve conflicts manually before pushing
4. **Permission Errors**: Ensure proper Azure service principal permissions

### Debug Commands
```powershell
# Test sync script locally
.\scripts\sync-sentinel-changes.ps1 -ResourceGroup "RG" -WorkspaceName "WS" -DryRun

# Force sync with vendor rules
.\scripts\sync-sentinel-changes.ps1 -ResourceGroup "RG" -WorkspaceName "WS" -IncludeVendorRules $true -ForceSync $true
```

## Benefits

This streamlined process provides:
- **Ease of Use**: Leverage Azure Sentinel portal's intuitive interface
- **Version Control**: All changes tracked in git with full history
- **Automated Deployment**: CI/CD pipeline handles deployments
- **Review Process**: Proper code review before production deployment
- **Environment Separation**: Clear distinction between DEV and PROD configurations
- **Vendor Rule Management**: Automated handling of vendor rule updates

The result is a more efficient, accurate, and collaborative rule development process that maintains the repository as the single source of truth while leveraging the power of the Sentinel portal interface.
