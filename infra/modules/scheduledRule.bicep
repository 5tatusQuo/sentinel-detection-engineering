// Required
param name string
param displayName string
param kql string
param workspaceName string

// Optional with defaults
@allowed(['Critical','High','Medium','Low','Informational'])
param severity string = 'Medium'
param enabled bool = true
param frequency string = 'PT1H'
param period string = 'PT1H'
param createIncident bool = true

// ATT&CK
param tactics array = []
param techniques array = []

// Advanced (partial objects allowed)
param grouping object = {}
param entities object = {}
param customDetails object = {}

// --- Merge caller-provided objects with safe defaults ---
var groupingDefaults = {
  enabled: true
  matchingMethod: 'AllEntities'   // or 'Selected'
  lookbackDuration: 'PT2H'
  reopenClosedIncident: false
  groupByEntities: []
  groupByAlertDetails: []
  groupByCustomDetails: []
}
var groupingEffective = union(groupingDefaults, grouping)

var entitiesDefaults = {
  accountFullName: null
  hostName: null
  ipAddress: null
}
var entitiesEffective = union(entitiesDefaults, entities)

var customDetailsDefaults = {}
var customDetailsEffective = union(customDetailsDefaults, customDetails)

// Stable ruleId
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
        enabled: groupingEffective.enabled
        matchingMethod: groupingEffective.matchingMethod
        lookbackDuration: groupingEffective.lookbackDuration
        reopenClosedIncident: groupingEffective.reopenClosedIncident
        groupByEntities: groupingEffective.groupByEntities
        groupByAlertDetails: groupingEffective.groupByAlertDetails
        groupByCustomDetails: groupingEffective.groupByCustomDetails
      }
    }

    // Entities (omit null mappings)
    entityMappings: length(entities) > 0 ? flatten([
      entitiesEffective.accountFullName != null ? [{
        entityType: 'Account'
        fieldMappings: [
          { identifier: 'FullName', columnName: string(entitiesEffective.accountFullName) }
        ]
      }] : []
      entitiesEffective.hostName != null ? [{
        entityType: 'Host'
        fieldMappings: [
          { identifier: 'HostName', columnName: string(entitiesEffective.hostName) }
        ]
      }] : []
      entitiesEffective.ipAddress != null ? [{
        entityType: 'IP'
        fieldMappings: [
          { identifier: 'Address', columnName: string(entitiesEffective.ipAddress) }
        ]
      }] : []
    ]) : []

    alertDetailsOverride: {
      alertDisplayNameFormat: displayName
    }

    // Custom details must match columns from the query output
    customDetails: customDetailsEffective
  }
}

// Outputs for monitoring
output ruleName string = rule.name
output ruleDisplayName string = rule.properties.displayName
output ruleEnabled bool = rule.properties.enabled
