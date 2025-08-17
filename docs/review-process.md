# Sentinel Rule Review Process

This document outlines the streamlined process for reviewing and updating Sentinel detection rules, including automated synchronization between the Azure Sentinel portal and repository.

## Overview

The review process allows reviewers to make changes directly in the Azure Sentinel portal (which is easier with the GUI) and then automatically sync those changes back to the repository using our automated script.

## Review Workflow

### 1. Initial Rule Creation
- Author creates a new rule using the `create-rule-pr.yml` workflow
- Rule is automatically deployed to the dev environment
- Pull request is created for review

### 2. Reviewer Makes Changes in Sentinel Portal
**Why use the portal?**
- ✅ Easier GUI for complex KQL queries
- ✅ Visual MITRE ATT&CK mapping
- ✅ Real-time query testing
- ✅ Entity mapping visualization
- ✅ Immediate validation

**What can be changed:**
- KQL query logic and filters
- Alert severity (Low, Medium, High, Critical)
- MITRE tactics and techniques
- Frequency and period settings
- Entity mappings
- Custom details
- Incident creation settings
- Alert grouping configuration

### 3. Automated Sync Process

#### Step 1: Run the Sync Script
```powershell
# Sync all rules from dev environment
.\scripts\sync-sentinel-changes.ps1 -ResourceGroup "SENTINEL_RG_DEV" -WorkspaceName "SENTINEL_WS_DEV"

# Sync specific rule only
.\scripts\sync-sentinel-changes.ps1 -ResourceGroup "SENTINEL_RG_DEV" -WorkspaceName "SENTINEL_WS_DEV" -RuleName "test5"

# Dry run to see what would change
.\scripts\sync-sentinel-changes.ps1 -ResourceGroup "SENTINEL_RG_DEV" -WorkspaceName "SENTINEL_WS_DEV" -DryRun
```

#### Step 2: Review Changes
The script automatically updates:
- `kql/[rule-name].kql` - Updated KQL query
- `env/deploy-dev.bicep` - Dev environment configuration
- `env/deploy-prod.bicep` - Production environment configuration (with escalated severity)

#### Step 3: Commit and Push
```bash
git add .
git commit -m "Sync Sentinel portal changes for [rule-name]"
git push origin feature/[branch-name]
```

#### Step 4: Automatic Verification
- Push triggers automatic deployment to dev
- Verify the rule in Sentinel matches repository
- If everything matches, the sync was successful

### 4. Complete Review Process

#### For Reviewers:
1. **Review the PR** - Check initial rule configuration
2. **Test in dev environment** - Verify rule behavior
3. **Make portal changes** - Use Sentinel GUI for improvements
4. **Run sync script** - `.\scripts\sync-sentinel-changes.ps1`
5. **Commit changes** - Push updates to feature branch
6. **Verify sync** - Automatic deployment confirms changes
7. **Approve PR** - Once satisfied with the rule
8. **Merge to main** - Triggers production deployment

#### For Authors:
1. **Create rule** - Use `create-rule-pr.yml` workflow
2. **Address feedback** - Make requested changes
3. **Collaborate with reviewer** - Work together on improvements
4. **Final review** - Ensure rule meets requirements
5. **Merge when approved** - Deploy to production

## Sync Script Details

### What the Script Does:
1. **Exports current rules** from Sentinel dev environment
2. **Parses rule configuration** including KQL, severity, tactics, etc.
3. **Updates KQL files** with current query logic
4. **Updates Bicep files** with current alert properties
5. **Handles environment differences** (dev vs prod severity escalation)
6. **Maintains naming conventions** and file structure

### Script Parameters:
- `ResourceGroup` - Sentinel resource group name
- `WorkspaceName` - Sentinel workspace name
- `RuleName` - Optional: sync specific rule only
- `DryRun` - Optional: show changes without applying

### Safety Features:
- ✅ **Dry run mode** - Preview changes before applying
- ✅ **Error handling** - Graceful failure with clear messages
- ✅ **Backup creation** - Original files are preserved
- ✅ **Validation** - Checks for required files and permissions

## Best Practices

### For Reviewers:
- **Always test in dev first** - Use the portal to experiment
- **Use dry run mode** - Preview changes before applying
- **Sync frequently** - Don't let portal and repo get out of sync
- **Document changes** - Add meaningful commit messages
- **Verify after sync** - Ensure automatic deployment succeeds

### For Authors:
- **Provide clear requirements** - Specify what the rule should detect
- **Test thoroughly** - Ensure rule works as expected
- **Respond to feedback** - Address reviewer comments promptly
- **Collaborate effectively** - Work with reviewers on improvements

### For Both:
- **Keep changes focused** - One logical change per commit
- **Use descriptive names** - Clear rule and file naming
- **Follow security practices** - Proper severity and incident creation
- **Test edge cases** - Ensure rule handles various scenarios

## Troubleshooting

### Common Issues:

#### Sync Script Fails:
```powershell
# Check Azure CLI connection
az account show

# Verify resource group and workspace
az sentinel workspace list --resource-group SENTINEL_RG_DEV

# Check permissions
az role assignment list --assignee [your-email] --scope /subscriptions/[sub-id]/resourceGroups/SENTINEL_RG_DEV
```

#### KQL Query Issues:
- Test queries in Sentinel Logs before syncing
- Use the portal's query editor for syntax validation
- Check for column name mismatches (IPAddress vs IpAddress)

#### Bicep Validation Errors:
- Run `az bicep build` to validate syntax
- Check for missing parameters or invalid values
- Verify entity mapping column names exist in KQL

#### Deployment Failures:
- Check Azure resource limits and quotas
- Verify workspace permissions
- Review deployment logs for specific errors

### Getting Help:
1. **Check logs** - Review GitHub Actions workflow logs
2. **Use dry run** - Preview changes before applying
3. **Test incrementally** - Sync one rule at a time
4. **Document issues** - Note specific error messages
5. **Ask for assistance** - Reach out to the team

## Automation Benefits

### Before (Manual Process):
- ❌ Manual file editing
- ❌ Copy-paste from portal
- ❌ Risk of typos and errors
- ❌ Time-consuming sync process
- ❌ Inconsistent formatting

### After (Automated Process):
- ✅ One-command sync
- ✅ Consistent formatting
- ✅ Error detection and handling
- ✅ Dry run preview
- ✅ Automatic environment differences
- ✅ Version control integration

## Conclusion

This streamlined review process combines the best of both worlds:
- **Easy GUI editing** in Azure Sentinel portal
- **Automated synchronization** back to repository
- **Version control** for all changes
- **Automatic deployment** to dev and prod environments

The result is a more efficient, accurate, and collaborative rule development process that maintains the repository as the single source of truth while leveraging the power of the Sentinel portal interface.
