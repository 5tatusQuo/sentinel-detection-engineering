@description('Log Analytics workspace name (Sentinel-enabled)')
param workspaceName string

@description('List of scheduled analytics rules to deploy')
param rules array = []



// Deploy each rule using the reusable module
module scheduled 'modules/scheduledRule.bicep' = [for r in rules: {
  name: 'rule-${uniqueString(r.name)}'
  scope: resourceGroup()
  params: {
    // required
    name: r.name                           // stable id seed (we'll GUID it inside)
    displayName: r.displayName
    kql: r.kql
    workspaceName: workspaceName
    // optional overrides with defaults inside the module
    enabled: r.enabled ?? true
    severity: r.severity ?? 'Medium'
    frequency: r.frequency ?? 'PT1H'
    period: r.period ?? 'PT1H'
    tactics: r.tactics ?? []
    techniques: r.techniques ?? []
    createIncident: r.createIncident ?? true
    grouping: r.grouping ?? {}
    entities: r.entities ?? {}
    customDetails: r.customDetails ?? {}
  }
}]

// Outputs for monitoring
output deployedRules array = [for r in rules: {
  name: r.name
  displayName: r.displayName
  enabled: r.enabled ?? true
}]
