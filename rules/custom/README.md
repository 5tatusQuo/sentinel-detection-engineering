# Custom Detection Rules

This directory contains authoritative Bicep templates for Microsoft Sentinel detection rules.

## Structure

- `*.bicep` - Detection rule templates
- `params/` - Environment-specific parameter files
  - `dev.jsonc` - Development environment parameters
  - `prod.jsonc` - Production environment parameters

## Template Guidelines

### Required Properties

Each detection rule template must include:

- `displayName`: Follow naming convention `[ORG] – <Thing Detected> (T####[#.###])`
- `description`: Clear description of what the rule detects
- `query`: KQL query for detection logic
- `severity`: Information, Low, Medium, High, or Critical
- `tactics`: MITRE ATT&CK tactics array
- `techniques`: MITRE ATT&CK techniques array
- `incidentConfiguration`: Incident creation settings

### Metadata

Include the `x_metadata` variable for tracking:

```bicep
var x_metadata = {
  upstreamTemplateGuid: ''      // For forked rules
  upstreamTemplateVersion: ''   // For forked rules
  owner: 'Detection Engineering'
}
```

### Parameters

Use parameters for environment-specific values:

- `ruleName`: Override display name if needed
- `severity`: Different severity per environment
- `enabled`: Enable/disable per environment
- `query`: Environment-specific query modifications

## Deployment

Rules are deployed automatically via GitHub Actions:

1. **Dev**: Deployed on merge to main
2. **Prod**: Deployed after manual approval

### Local Testing

```bash
# Build template
az bicep build --file rules/custom/your-rule.bicep

# What-if deployment
az deployment group what-if \
  --resource-group $SENTINEL_RG_DEV \
  --template-file rules/custom/your-rule.bicep \
  --parameters rules/custom/params/dev.jsonc
```

## Adding a New Rule

1. Create new `.bicep` file following naming convention
2. Add parameters to `params/dev.jsonc` and `params/prod.jsonc`
3. Test locally with `az bicep build`
4. Create PR - automatic deployment to Dev
5. Request Prod deployment approval

## Validation

All templates are validated during deployment:

- Bicep syntax validation
- Resource group what-if analysis
- Query syntax verification (smoke test)
