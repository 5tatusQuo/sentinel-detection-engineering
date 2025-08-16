@description('Log Analytics workspace name (Sentinel-enabled)')
param workspaceName string

@description('List of scheduled analytics rules to deploy')
param rules array = []

resource la 'Microsoft.OperationalInsights/workspaces@2022-10-01' existing = {
  name: workspaceName
}

module scheduled 'modules/scheduledRule.bicep' = [for r in rules: {
  name: 'rule-${uniqueString(r.name)}'
  scope: la
  params: {
    // required
    name:        r.name
    displayName: r.displayName
    kql:         r.kql
    severity:    r.severity
    enabled:     bool(r.enabled)
    frequency:   r.frequency
    period:      r.period
    tactics:     r.tactics
    techniques:  r.techniques
    createIncident: bool(r.createIncident)

    // optional
    grouping:      contains(r,'grouping')      ? r.grouping      : {}
    entities:      contains(r,'entities')      ? r.entities      : []
    customDetails: contains(r,'customDetails') ? r.customDetails : {}
  }
}]
