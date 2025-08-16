param name string                 // a stable string; we derive the resource name from it
param displayName string
param kql string
param workspaceName string        // workspace name for scoping

@allowed(['Critical','High','Medium','Low','Informational'])
param severity string = 'Medium'
param enabled bool = true
param frequency string = 'PT1H'
param period string = 'PT1H'
param createIncident bool = true

@description('ATT&CK')
param tactics array = []
param techniques array = []

@description('Grouping settings (optional)')
param grouping object = {
  enabled: true
  matchingMethod: 'AllEntities'   // or 'Selected'
  lookbackDuration: 'PT2H'
  reopenClosedIncident: false
  groupByEntities: []             // used if matchingMethod = Selected
  groupByAlertDetails: []
  groupByCustomDetails: []
}

@description('Entity mappings (optional). Example: { accountFullName: "SubjectUserName", hostName: "Computer" }')
param entities object = {}

@description('Alert custom details (optional). Example: { EncodedArgument: "EncArg", CommandLine: "CommandLine" }')
param customDetails object = {}

var ruleId = guid(deployment().name, name)

// Reference the workspace for scoping
resource la 'Microsoft.OperationalInsights/workspaces@2022-10-01' existing = {
  name: workspaceName
}

resource rule 'Microsoft.SecurityInsights/alertRules@2025-06-01' = {
  scope: la
  name: ruleId
  kind: 'Scheduled'
  properties: {
    displayName: displayName
    description: 'Scheduled analytics rule deployed via Bicep.'
    enabled: enabled
    severity: severity
    query: kql
    queryFrequency: frequency
    queryPeriod: period
    triggerOperator: 'GreaterThan'
    triggerThreshold: 0
    tactics: tactics
    techniques: techniques
    suppressionEnabled: false
    suppressionDuration: 'PT5M'
    incidentConfiguration: {
      createIncident: createIncident
      groupingConfiguration: {
        enabled: grouping.enabled
        reopenClosedIncident: grouping.reopenClosedIncident
        lookbackDuration: grouping.lookbackDuration
        matchingMethod: grouping.matchingMethod
        groupByEntities: grouping.groupByEntities
        groupByAlertDetails: grouping.groupByAlertDetails
        groupByCustomDetails: grouping.groupByCustomDetails
      }
    }
    // Map only if provided
    entityMappings: length(entities) > 0 ? flatten([
      entities.accountFullName != null ? [{
        entityType: 'Account'
        fieldMappings: [
          { identifier: 'FullName', columnName: string(entities.accountFullName) }
        ]
      }] : []
      entities.hostName != null ? [{
        entityType: 'Host'
        fieldMappings: [
          { identifier: 'HostName', columnName: string(entities.hostName) }
        ]
      }] : []
      entities.ipAddress != null ? [{
        entityType: 'IP'
        fieldMappings: [
          { identifier: 'Address', columnName: string(entities.ipAddress) }
        ]
      }] : []
    ]) : []
    alertDetailsOverride: {
      alertDisplayNameFormat: displayName
    }
    customDetails: customDetails
  }
}

// Outputs for monitoring
output ruleName string = rule.name
output ruleDisplayName string = rule.properties.displayName
output ruleEnabled bool = rule.properties.enabled
