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
  // Account entity mappings
  accountFullName: null
  accountName: null
  accountUpnSuffix: null
  accountDnsDomain: null
  accountNtDomain: null
  accountSid: null
  accountObjectGuid: null
  
  // Host entity mappings
  hostName: null
  hostFullName: null
  hostDnsDomain: null
  hostNtDomain: null
  hostNetBiosName: null
  hostAzureId: null
  hostOmsAgentId: null
  
  // IP entity mappings
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

    // Entities: only include non-null mappings
    entityMappings: length(entities) > 0 ? flatten([
      // Account entity mappings
      e.accountFullName != null ? [{
        entityType: 'Account'
        fieldMappings: [
          { identifier: 'FullName', columnName: string(e.accountFullName) }
        ]
      }] : []
      e.accountName != null ? [{
        entityType: 'Account'
        fieldMappings: [
          { identifier: 'Name', columnName: string(e.accountName) }
        ]
      }] : []
      e.accountUpnSuffix != null ? [{
        entityType: 'Account'
        fieldMappings: [
          { identifier: 'UPNSuffix', columnName: string(e.accountUpnSuffix) }
        ]
      }] : []
      e.accountDnsDomain != null ? [{
        entityType: 'Account'
        fieldMappings: [
          { identifier: 'DNSDomain', columnName: string(e.accountDnsDomain) }
        ]
      }] : []
      e.accountNtDomain != null ? [{
        entityType: 'Account'
        fieldMappings: [
          { identifier: 'NTDomain', columnName: string(e.accountNtDomain) }
        ]
      }] : []
      e.accountSid != null ? [{
        entityType: 'Account'
        fieldMappings: [
          { identifier: 'Sid', columnName: string(e.accountSid) }
        ]
      }] : []
      e.accountObjectGuid != null ? [{
        entityType: 'Account'
        fieldMappings: [
          { identifier: 'ObjectGuid', columnName: string(e.accountObjectGuid) }
        ]
      }] : []
      
      // Host entity mappings
      e.hostName != null ? [{
        entityType: 'Host'
        fieldMappings: [
          { identifier: 'HostName', columnName: string(e.hostName) }
        ]
      }] : []
      e.hostFullName != null ? [{
        entityType: 'Host'
        fieldMappings: [
          { identifier: 'FullName', columnName: string(e.hostFullName) }
        ]
      }] : []
      e.hostDnsDomain != null ? [{
        entityType: 'Host'
        fieldMappings: [
          { identifier: 'DnsDomain', columnName: string(e.hostDnsDomain) }
        ]
      }] : []
      e.hostNtDomain != null ? [{
        entityType: 'Host'
        fieldMappings: [
          { identifier: 'NTDomain', columnName: string(e.hostNtDomain) }
        ]
      }] : []
      e.hostNetBiosName != null ? [{
        entityType: 'Host'
        fieldMappings: [
          { identifier: 'NetBiosName', columnName: string(e.hostNetBiosName) }
        ]
      }] : []
      e.hostAzureId != null ? [{
        entityType: 'Host'
        fieldMappings: [
          { identifier: 'AzureID', columnName: string(e.hostAzureId) }
        ]
      }] : []
      e.hostOmsAgentId != null ? [{
        entityType: 'Host'
        fieldMappings: [
          { identifier: 'OMSAgentID', columnName: string(e.hostOmsAgentId) }
        ]
      }] : []
      
      // IP entity mappings
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
