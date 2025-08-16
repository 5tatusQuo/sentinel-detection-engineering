# Approvals Process

This document explains how to set up and use approval gates in the Microsoft Sentinel detection engineering pipeline.

## GitHub Environment Protection

### Setting Up the `sentinel-prod` Environment

1. **Navigate to Repository Settings**
   - Go to your repository on GitHub
   - Click **Settings** → **Environments**

2. **Create New Environment**
   - Click **New environment**
   - Name: `sentinel-prod`
   - Description: `Production Sentinel workspace deployment protection`

3. **Configure Protection Rules**
   - **Required reviewers**: Add Detection Engineering team members
   - **Wait timer**: 0 minutes (immediate approval)
   - **Deployment branches**: `main` only
   - **Environment secrets**: None required (uses repository secrets)

### Environment Configuration Example

```yaml
# .github/environments/sentinel-prod.yml
name: sentinel-prod
protection_rules:
  required_reviewers:
    - username: security-admin
    - username: detection-engineer
  wait_timer: 0
  deployment_branches:
    - main
```

## Approval Workflow

### 1. Dev Deployment (Automatic)
- **Trigger**: Merge to main branch
- **Approval**: None required
- **Purpose**: Testing and validation
- **Configuration**: Uses `params/dev.jsonc`

### 2. Prod Deployment (Manual Approval)
- **Trigger**: After successful Dev deployment
- **Approval**: Required from `sentinel-prod` environment
- **Purpose**: Production deployment
- **Configuration**: Uses `params/prod.jsonc`

### Approval Process Steps

1. **Dev Deployment Completes**
   - Pipeline automatically deploys to Dev
   - Validation and smoke tests run
   - If successful, Prod deployment job starts

2. **Approval Request**
   - GitHub creates approval request
   - Notification sent to required reviewers
   - Deployment paused until approval

3. **Review Process**
   - Reviewers examine changes
   - Check validation results
   - Verify Dev deployment success

4. **Approval Decision**
   - **Approve**: Deployment proceeds to Prod
   - **Reject**: Deployment cancelled, investigation required

## Review Checklist

### Pre-Approval Review

**Code Quality**
- [ ] Bicep templates validated successfully
- [ ] No syntax errors in queries
- [ ] Parameter files properly configured
- [ ] Naming conventions followed

**Security Review**
- [ ] ATT&CK techniques properly mapped
- [ ] Severity levels appropriate
- [ ] Incident configuration reviewed
- [ ] Data sources verified

**Testing Results**
- [ ] Dev deployment successful
- [ ] Smoke tests passed
- [ ] No critical errors in logs
- [ ] Rule enablement verified

**Operational Impact**
- [ ] Query performance acceptable
- [ ] False positive rate considered
- [ ] Incident grouping appropriate
- [ ] Rollback plan available

### Approval Decision Criteria

**Approve When:**
- All checklist items completed
- Dev deployment successful
- No security concerns
- Performance impact acceptable
- Team consensus reached

**Reject When:**
- Critical issues identified
- Security concerns raised
- Performance problems detected
- Insufficient testing completed
- Team disagreement exists

## Emergency Approvals

### Emergency Deployment Process

1. **Create Emergency PR**
   - Branch from main
   - Make minimal required changes
   - Add `[EMERGENCY]` prefix to title

2. **Expedited Review**
   - Notify all reviewers immediately
   - Focus on critical changes only
   - Skip non-critical validations

3. **Emergency Approval**
   - Use emergency approval process
   - Document reason for expedited deployment
   - Plan post-deployment review

### Emergency Approval Criteria

- **Immediate Security Threat**: Active incident requiring new detection
- **Critical Bug Fix**: Rule causing system issues
- **Compliance Deadline**: Regulatory requirement
- **Service Outage**: Detection pipeline failure

## Approval Roles and Responsibilities

### Detection Engineering Team
- **Primary Reviewers**: All team members
- **Responsibilities**:
  - Technical review of changes
  - Security assessment
  - Performance evaluation
  - Operational impact analysis

### Security Operations Team
- **Secondary Reviewers**: Security analysts
- **Responsibilities**:
  - False positive assessment
  - Incident response impact
  - Coverage gap analysis
  - Threat intelligence integration

### Platform Team
- **Consultation**: As needed
- **Responsibilities**:
  - Infrastructure impact
  - Resource utilization
  - Integration issues
  - Performance optimization

## Approval Notifications

### Automatic Notifications
- **GitHub**: Environment protection notifications
- **Email**: Repository notification settings
- **Slack/Teams**: Webhook integration (optional)

### Manual Notifications
- **Emergency**: Direct message to all reviewers
- **High Priority**: Team chat notification
- **Standard**: Repository discussion

## Approval Metrics

### Tracking Metrics
- **Approval Time**: Average time to approval
- **Rejection Rate**: Percentage of rejected deployments
- **Emergency Deployments**: Frequency of emergency approvals
- **Review Quality**: Post-deployment issue rate

### Continuous Improvement
- **Monthly Review**: Analyze approval patterns
- **Process Optimization**: Streamline review process
- **Training**: Improve reviewer capabilities
- **Documentation**: Update review guidelines

## Troubleshooting

### Common Issues

1. **Approval Not Received**
   - Check reviewer availability
   - Verify notification settings
   - Use manual notification
   - Consider emergency process

2. **Environment Not Found**
   - Verify environment exists
   - Check environment name spelling
   - Ensure repository access
   - Review environment configuration

3. **Approval Permissions**
   - Verify reviewer permissions
   - Check team membership
   - Review environment protection rules
   - Contact repository admin

### Escalation Process

1. **Primary Escalation**: Detection Engineering lead
2. **Secondary Escalation**: Security team lead
3. **Tertiary Escalation**: Platform team lead
4. **Final Escalation**: CISO or equivalent

## Best Practices

### For Reviewers
- **Timely Response**: Respond within 4 hours
- **Thorough Review**: Complete all checklist items
- **Documentation**: Record review decisions
- **Continuous Learning**: Stay updated on threats

### For Developers
- **Clear Documentation**: Explain changes thoroughly
- **Testing**: Ensure Dev deployment success
- **Communication**: Notify team of changes
- **Preparation**: Have rollback plan ready

### For Teams
- **Regular Training**: Keep reviewers skilled
- **Process Review**: Optimize approval workflow
- **Tool Integration**: Use automation where possible
- **Metrics Tracking**: Monitor approval effectiveness
