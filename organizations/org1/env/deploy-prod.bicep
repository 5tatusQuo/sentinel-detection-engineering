// Prod environment wrapper - loads KQL files and configures rules
@description('Log Analytics workspace name (Sentinel-enabled)')
param workspaceName string = 'sentinel-rg-prod'

// Load KQL files for prod environment
var kqlcustomrule1 = loadTextContent('../kql/prod/customrule1.kql')
var kqlcustomrule2 = loadTextContent('../kql/prod/customrule2.kql')
var kqlcustomrule3 = loadTextContent('../kql/prod/customrule3.kql')

// Define rules for prod environment
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
  },{
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
  }
]