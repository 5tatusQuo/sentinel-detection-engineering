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

// Entities will be passed directly as the raw Azure Sentinel structure

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
      groupingConfiguration: {
        enabled: g.enabled
        matchingMethod: g.matchingMethod
        lookbackDuration: g.lookbackDuration
        reopenClosedIncident: g.reopenClosedIncident
        groupByEntities: g.groupByEntities
        groupByAlertDetails: g.groupByAlertDetails
        groupByCustomDetails: g.groupByCustomDetails
      }
    }

    // Pass entity mappings directly from Azure Sentinel structure
    entityMappings: entities

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
