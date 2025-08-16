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

// ATT&CK (NOTE: techniques must be T#### at this API level)
param tactics array = []
param techniques array = []

// Advanced (partial objects allowed)
param grouping object = {}
param entities object = {}
param customDetails object = {}

// Merge caller objects with defaults
var groupingDefaults = {
  enabled: true
  matchingMethod: 'AllEntities'   // or 'Selected'
  // the following are only valid for 'Selected' on many API versions
  lookbackDuration: 'PT2H'
  reopenClosedIncident: false
  groupByEntities: []
  groupByAlertDetails: []
  groupByCustomDetails: []
}
var g = union(groupingDefaults, grouping)

var entitiesDefaults = {
  accountFullName: null
  hostName: null
  ipAddress: null
}
var e = union(entitiesDefaults, entities)

var cd = customDetails // no defaults needed

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
      groupingConfiguration: g.matchingMethod == 'Selected'
        ? {
            enabled: g.enabled
            matchingMethod: 'Selected'
            lookbackDuration: g.lookbackDuration
            reopenClosedIncident: g.reopenClosedIncident
            groupByEntities: g.groupByEntities
            groupByAlertDetails: g.groupByAlertDetails
            groupByCustomDetails: g.groupByCustomDetails
          }
        : {
            enabled: g.enabled
            matchingMethod: 'AllEntities'
          }
    }

    // Entities: only include non-null mappings
    entityMappings: length(entities) > 0 ? flatten([
      e.accountFullName != null ? [{
        entityType: 'Account'
        fieldMappings: [
          { identifier: 'FullName', columnName: string(e.accountFullName) }
        ]
      }] : []
      e.hostName != null ? [{
        entityType: 'Host'
        fieldMappings: [
          { identifier: 'HostName', columnName: string(e.hostName) }
        ]
      }] : []
      e.ipAddress != null ? [{
        entityType: 'IP'
        fieldMappings: [
          { identifier: 'Address', columnName: string(e.ipAddress) }
        ]
      }] : []
    ]) : []

    alertDetailsOverride: {
      alertDisplayNameFormat: displayName
    }

    customDetails: cd
  }
}

// Outputs for monitoring
output ruleName string = rule.name
output ruleDisplayName string = rule.properties.displayName
output ruleEnabled bool = rule.properties.enabled
