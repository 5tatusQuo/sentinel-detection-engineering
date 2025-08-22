var kqlcustomrule1 = loadTextContent('../kql/dev/customrule1.kql')
var kqlcustomrule2 = loadTextContent('../kql/dev/customrule2.kql')
var kqlcustomrule3 = loadTextContent('../kql/dev/customrule3.kql')

// Dev environment wrapper - loads KQL files and configures rules
@description('Log Analytics workspace name (Sentinel-enabled)')
param workspaceName string = 'sentinel-rg-dev'

// Rules will be populated by sync script
var rules = [
  {
    name: 'customrule1'
    displayName: 'CustomRule1'
    kql: kqlcustomrule1
    severity: 'Medium'
    enabled: true
    frequency: 'PT5M'
    period: 'PT5M'
    tactics: [ 'InitialAccess' ]
    techniques: [  ]
    createIncident: true
    grouping: {
      enabled: false
      matchingMethod: 'AllEntities'
    }
    entities: {
      accountFullName: 'Caller'
    }
    customDetails: {
      // TODO: Sync customDetails if needed
    }
  },
  {
    name: 'customrule2'
    displayName: 'CustomRule2'
    kql: kqlcustomrule2
    severity: 'Medium'
    enabled: true
    frequency: 'PT5M'
    period: 'PT5M'
    tactics: [ 'InitialAccess' ]
    techniques: [  ]
    createIncident: true
    grouping: {
      enabled: false
      matchingMethod: 'AllEntities'
    }
    entities: {
      accountFullName: 'Caller'
    }
    customDetails: {
      // TODO: Sync customDetails if needed
    }
  },
  {
    name: 'customrule3'
    displayName: 'CustomRule3'
    kql: kqlcustomrule3
    severity: 'Medium'
    enabled: true
    frequency: 'PT5M'
    period: 'PT5M'
    tactics: [ 'InitialAccess' ]
    techniques: [  ]
    createIncident: true
    grouping: {
      enabled: false
      matchingMethod: 'AllEntities'
    }
    entities: {
      accountFullName: 'Caller'
    }
    customDetails: {
      // TODO: Sync customDetails if needed
    }
  }
]

// Deploy rules using the main module
module sentinelRules '../../../infra/sentinel-rules.bicep' = {
  name: 'sentinel-rules-dev'
  params: {
    workspaceName: workspaceName
    rules: rules
  }
}

// Outputs
output deployedRules array = sentinelRules.outputs.deployedRules
