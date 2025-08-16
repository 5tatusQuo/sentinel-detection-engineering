# Naming and Metadata Standards

This document defines the naming conventions and metadata standards for Microsoft Sentinel detection rules.

## Rule Naming Convention

### Format
```
[ORG] – <Thing Detected> (T####[#.###])
```

### Components
- **`[ORG]`**: Organization prefix (e.g., UBH, ACME, CORP)
- **`<Thing Detected>`**: Clear description of what the rule detects
- **`(T####[#.###])`**: MITRE ATT&CK technique identifier

### Examples
- `[ORG] – Suspicious PowerShell (EncodedCommand) (T1059.001)`
- `[ORG] – Lateral Movement via RDP (T1021.001)`
- `[ORG] – Credential Dumping via Mimikatz (T1003.001)`
- `[ORG] – Suspicious Process Creation (T1055)`

### Guidelines
- Use clear, descriptive names
- Include the specific technique when possible
- Avoid generic terms like "malicious" or "suspicious" without context
- Keep names under 100 characters
- Use proper capitalization and spacing

## Metadata Standards

### Required Metadata

Each detection rule must include the following metadata:

```bicep
var x_metadata = {
  upstreamTemplateGuid: ''      // For forked rules
  upstreamTemplateVersion: ''   // For forked rules
  owner: 'Detection Engineering'
}
```

### Metadata Fields

| Field | Description | Required | Example |
|-------|-------------|----------|---------|
| `upstreamTemplateGuid` | Original template GUID for forked rules | No | `'12345678-1234-1234-1234-123456789012'` |
| `upstreamTemplateVersion` | Version of original template | No | `'1.0.0'` |
| `owner` | Team responsible for the rule | Yes | `'Detection Engineering'` |

### Additional Metadata (Optional)

```bicep
var x_metadata = {
  upstreamTemplateGuid: ''
  upstreamTemplateVersion: ''
  owner: 'Detection Engineering'
  dataSources: ['SecurityEvent', 'Sysmon']
  tags: ['powershell', 'obfuscation']
  references: ['https://attack.mitre.org/techniques/T1059/001/']
  falsePositiveRate: 'Low'
  maintenanceNotes: 'Monitor for false positives in development environments'
}
```

## MITRE ATT&CK Mapping

### Required Fields
- **`tactics`**: Array of MITRE ATT&CK tactics
- **`techniques`**: Array of MITRE ATT&CK technique IDs

### Mapping Guidelines
1. **Primary Technique**: Map to the most specific technique that applies
2. **Secondary Techniques**: Include related techniques if the rule detects multiple behaviors
3. **Tactics**: Include all relevant tactics (e.g., Execution + DefenseEvasion for obfuscated code)

### Example Mapping
```bicep
param tactics array = [
  'Execution'
  'DefenseEvasion'
]

param techniques array = [
  'T1059.001'  // PowerShell
  'T1027'      // Obfuscated Files or Information
]
```

## Forked Rules

### When to Fork
- Customizing vendor rules for your environment
- Adding organization-specific logic
- Modifying severity or incident configuration
- Extending detection coverage

### Forking Process
1. **Create New Rule**: Generate new GUID for the rule
2. **Disable Original**: Disable the original vendor rule
3. **Record Lineage**: Document upstream template information
4. **Customize**: Modify query, severity, or configuration as needed
5. **Test**: Validate in Dev environment before production

### Forked Rule Example
```bicep
var x_metadata = {
  upstreamTemplateGuid: '87654321-4321-4321-4321-210987654321'
  upstreamTemplateVersion: '1.2.0'
  owner: 'Detection Engineering'
}

// Original: "Suspicious PowerShell Execution"
// Modified: "[ORG] – Suspicious PowerShell (EncodedCommand) (T1059.001)"
param ruleName string = '[ORG] – Suspicious PowerShell (EncodedCommand) (T1059.001)'
```

## Data Source Documentation

### Required Information
- **Primary Data Source**: Main table used (e.g., `SecurityEvent`, `Sysmon`)
- **Dependencies**: Any data connectors or solutions required
- **Coverage**: What systems/environments are covered

### Example Data Source Documentation
```bicep
// Data Sources: SecurityEvent (Windows Security Logs)
// Dependencies: Microsoft Sentinel Windows Security Events connector
// Coverage: All Windows systems with Security auditing enabled
// Query filters: EventID 4104 (PowerShell script block logging)
```

## Severity Guidelines

### Severity Levels
- **Critical**: Immediate response required, high confidence
- **High**: Urgent investigation, medium-high confidence
- **Medium**: Standard investigation, medium confidence
- **Low**: Informational, low confidence or noisy
- **Informational**: No immediate action, monitoring only

### Severity Criteria
- **Confidence**: How certain is the detection?
- **Impact**: What's the potential damage?
- **Prevalence**: How common is this behavior?
- **False Positive Rate**: Expected noise level

## Incident Configuration

### Standard Configuration
```bicep
incidentConfiguration: {
  createIncident: true
  groupingConfiguration: {
    enabled: true
    lookbackDuration: 'PT5M'
    matchingMethod: 'GroupByAlertDetails'
    groupByEntities: ['Computer', 'SubjectUserName']
    reopenClosedIncident: false
  }
}
```

### Grouping Guidelines
- **Group by Host**: When multiple alerts from same system
- **Group by User**: When multiple alerts from same user
- **Group by Time**: When alerts occur within short timeframe
- **Single Alert**: For unique, standalone detections

## Quality Assurance

### Pre-Deployment Checklist
- [ ] Naming convention followed
- [ ] ATT&CK mapping accurate
- [ ] Metadata complete
- [ ] Data sources documented
- [ ] Severity appropriate
- [ ] Incident configuration reviewed
- [ ] Query tested in Dev environment

### Post-Deployment Validation
- [ ] Rule enabled and running
- [ ] No syntax errors in logs
- [ ] Expected data sources available
- [ ] Incident creation working
- [ ] Performance acceptable

## Maintenance

### Regular Reviews
- **Monthly**: Review rule effectiveness
- **Quarterly**: Update ATT&CK mappings
- **Annually**: Review and update metadata

### Documentation Updates
- Keep metadata current
- Update references and links
- Document any customizations
- Record maintenance activities
