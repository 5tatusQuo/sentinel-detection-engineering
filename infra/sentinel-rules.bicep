@description('Log Analytics workspace name (Sentinel-enabled)')
param workspaceName string

@description('List of scheduled analytics rules to deploy')
param rules array = []



module scheduled 'modules/scheduledRule.bicep' = [for r in rules: {
  name: 'rule-${uniqueString(r.name)}'
  scope: resourceGroup()
  params: {
    // required
    name:          r.name
    displayName:   r.displayName
    kql:           r.kql
    workspaceName: workspaceName

    // common optional (defaults set in module)
    severity:      r.severity
    enabled:       (r.enabled == null) ? true : bool(r.enabled)
    frequency:     r.frequency
    period:        r.period
    createIncident:r.createIncident

    // ATT&CK
    tactics:       r.tactics
    techniques:    r.techniques

    // advanced
    grouping:      r.grouping
    entities:      r.entities
    customDetails: r.customDetails
  }
}]

// Outputs for monitoring
output deployedRules array = [for r in rules: {
  name: r.name
  displayName: r.displayName
  enabled: r.enabled ?? true
}]
