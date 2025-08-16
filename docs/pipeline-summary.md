# Pipeline Overview

This document provides a high-level overview of the Microsoft Sentinel detection engineering pipeline.

## Architecture

The pipeline follows a **GitOps** approach where:

1. **Source of Truth**: Bicep templates in `rules/custom/` define the desired state
2. **Automated Deployment**: GitHub Actions deploy changes to Dev → Prod environments
3. **Drift Detection**: Automated checks ensure actual state matches desired state
4. **Vendor Management**: Automated export of vendor rules for tracking

## Pipeline Components

### 1. Development Workflow

```
Developer → PR → Build/Validate → Deploy to Dev → Manual Approval → Deploy to Prod
```

**Steps:**
1. Developer creates/modifies Bicep templates in `rules/custom/`
2. Creates PR with changes
3. Automated validation (Bicep build, what-if deployment)
4. On merge to main: automatic deployment to Dev
5. Manual approval required for Prod deployment

### 2. Nightly Export (`vendor-sync.yml`)

**Purpose**: Capture vendor rule changes and maintain visibility

**Schedule**: Daily at 2 AM UTC

**Process:**
1. Export enabled rules from Sentinel workspaces
2. Compare with previous exports
3. Create PR if changes detected
4. Review and merge vendor rule updates

### 3. Drift Detection (`drift-check.yml`)

**Purpose**: Ensure workspace state matches desired state

**Schedule**: Weekly on Sundays at 3 AM UTC

**Process:**
1. Compare Bicep templates with actual workspace state
2. Generate detailed drift report
3. Create PR with findings if drift detected
4. Manual investigation and remediation

## Environment Strategy

### Dev Environment
- **Purpose**: Testing and validation
- **Deployment**: Automatic on merge to main
- **Configuration**: Lower severity, no incident creation, limited data
- **Parameters**: `rules/custom/params/dev.jsonc`

### Prod Environment
- **Purpose**: Production detection rules
- **Deployment**: Manual approval required
- **Configuration**: Full severity, incident creation enabled
- **Parameters**: `rules/custom/params/prod.jsonc`

## Security & Approvals

### GitHub Environment Protection
- **Environment**: `sentinel-prod`
- **Required Reviewers**: Detection Engineering team
- **Protection Rules**: 
  - Require pull request reviews
  - Require status checks to pass
  - Restrict pushes to matching branches

### Approval Process
1. **Dev Deployment**: Automatic (no approval needed)
2. **Prod Deployment**: Manual approval required
3. **Review Checklist**:
   - [ ] Query syntax validated
   - [ ] ATT&CK mapping verified
   - [ ] Incident configuration reviewed
   - [ ] Dev environment tests passed
   - [ ] Severity appropriate for production

## Rollback Strategy

### Immediate Rollback
1. Revert the problematic PR
2. Create new PR with reverted changes
3. Pipeline automatically redeploys previous state

### Emergency Rollback
1. Disable rules directly in Azure portal
2. Create emergency PR to disable in Bicep
3. Deploy emergency fix
4. Investigate and create proper fix

## Monitoring & Alerts

### Pipeline Health
- GitHub Actions status
- Deployment success/failure notifications
- Drift detection alerts

### Rule Health
- Rule enablement status
- Query performance monitoring
- False positive tracking

## Best Practices

### Development
- Always test in Dev first
- Use parameter files for environment differences
- Follow naming conventions
- Include proper metadata

### Deployment
- Review what-if output before deployment
- Monitor deployment logs
- Verify post-deployment state
- Test incident creation in Dev

### Maintenance
- Regular drift detection reviews
- Vendor rule updates
- Performance optimization
- Documentation updates

## Troubleshooting

### Common Issues

1. **Bicep Build Failures**
   - Check syntax errors
   - Validate parameter files
   - Verify resource dependencies

2. **Deployment Failures**
   - Check Azure permissions
   - Verify resource group exists
   - Review error messages in logs

3. **Drift Detection**
   - Investigate manual changes
   - Update Bicep templates
   - Redeploy to sync state

### Support Contacts
- **Detection Engineering Team**: Primary support
- **Azure Platform Team**: Infrastructure issues
- **Security Operations**: Rule effectiveness questions
