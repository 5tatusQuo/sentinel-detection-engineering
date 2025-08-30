# 🚨 Troubleshooting Guide

## Common Issues

### 1. Configuration Errors

**Symptoms**: Deployment failures, validation errors, organization not found

**Solutions**:
- Run `pwsh -File scripts/validate-bicep.ps1` to validate all configurations
- Check JSON syntax in `config/organizations.json`
- Verify organization directory structure exists
- Ensure required files are present in `organizations/orgX/env/` and `organizations/orgX/kql/`

### 2. KQL Syntax Errors

**Symptoms**: Rule deployment fails, template validation errors

**Solutions**:
- Test your KQL query in Azure Sentinel Logs first
- Validate regex patterns and KQL functions
- Check column names referenced in entity mappings match query output
- Ensure proper KQL syntax (pipe operators, functions, etc.)

### 3. Deployment Failures

**Symptoms**: Bicep deployment errors, ARM template failures

**Solutions**:
- Check Bicep build output for syntax errors
- Verify Azure permissions (Contributor on resource group minimum)
- Review what-if analysis before deployment
- Check Azure resource names match configuration
- Ensure Sentinel workspace is properly configured

### 4. Sync Issues

**Symptoms**: Drift detection fails, portal sync doesn't work

**Solutions**:
- Check Azure authentication: `az login` and `az account show`
- Verify workspace names and resource groups in configuration
- Review sync workflow logs in GitHub Actions
- Ensure Git identity is configured in workflows
- Check API permissions on Sentinel workspace

### 5. Entity Mapping Errors

**Symptoms**: Deployment succeeds but entity extraction fails

**Solutions**:
- Check `rules-*.json` for proper entity mapping format
- Ensure KQL query returns columns referenced in entity mappings
- Azure expects `entityMappings` as arrays, not objects
- Sync script automatically converts formats during sync

### 6. GitOps Workflow Issues

**Symptoms**: PRs not created, drift not detected

**Solutions**:
- Verify drift detection is working (rules missing from prod)
- Check PR creation logic for both file changes and empty commits
- Ensure GitHub Actions has proper permissions for branch/PR creation
- Review workflow logs for authentication issues

### 7. Multi-Organization Issues

#### "Configuration file not found"
- **Error**: `Configuration file not found: config/organizations.json`
- **Fix**: Ensure the file exists and is committed to git (not ignored)
- **Check**: Run `git add config/organizations.json` if needed

#### "Organization not found in config"
- **Error**: `Organization 'org1' not found in configuration`
- **Fix**: Add the organization to `config/organizations.json`
- **Check**: Verify the organization name matches exactly (case-sensitive)

#### "Resource group/workspace mismatch"
- **Error**: Deployment fails due to wrong resource group/workspace
- **Fix**: Verify `config/organizations.json` has correct Azure resource names
- **Check**: Compare with actual Azure resources using `az resource list`

### 8. Bicep Template Issues

#### "Property doesn't exist" Error
- **Symptoms**: Template compilation fails with missing property errors
- **Fix**: Ensure all rule objects have the same properties
- **Solution**: Use empty objects for optional properties: `grouping: {}`, `customDetails: {}`

#### "KQL variable not defined"
- **Error**: Variables like `kqlCustomRule1` are not defined
- **Fix**: Run the drift detection & sync workflow to regenerate Bicep files
- **Check**: Verify KQL files exist in correct organization/environment directories

#### KQL Column Errors
- **Symptoms**: Rules deploy but don't extract entities properly
- **Fix**: Ensure columns referenced in `entities` or `customDetails` are returned by KQL query
- **Test**: Run query in Sentinel Logs and verify column names

## Debug Mode

For detailed troubleshooting, run scripts with verbose output:

```powershell
# Verbose script execution
.\scripts\export_enabled_rules.ps1 -Verbose
.\scripts\sync-sentinel-changes.ps1 -Verbose
.\scripts\validate-bicep.ps1 -Verbose
.\scripts\deploy-organizations.ps1 -Environment "dev" -Verbose
```

## Validation Commands

```powershell
# Validate all organization configurations
pwsh -File scripts/validate-bicep.ps1

# Test specific organization Bicep
az bicep build --file organizations/org1/env/deploy-dev.bicep

# Check Azure connectivity
az account show
az group list

# Validate JSON configuration
Get-Content config/organizations.json | ConvertFrom-Json
```

## Getting Help

If you're still stuck:

1. **Check GitHub Actions logs** for detailed error messages
2. **Run scripts locally** with `-Verbose` flag to see execution details
3. **Test Azure connectivity** and permissions
4. **Validate configuration files** with JSON/Bicep tools
5. **Create an issue** in this repository with error details
6. **Contact the Detection Engineering team**

## Useful Resources

- [Microsoft Sentinel Documentation](https://docs.microsoft.com/en-us/azure/sentinel/)
- [KQL Quick Reference](https://docs.microsoft.com/en-us/azure/data-explorer/kql-quick-reference)
- [Bicep Documentation](https://docs.microsoft.com/en-us/azure/azure-resource-manager/bicep/)
- [Azure CLI Documentation](https://docs.microsoft.com/en-us/cli/azure/)
