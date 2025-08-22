// Prod environment wrapper - loads KQL files and configures rules
@description('Log Analytics workspace name (Sentinel-enabled)')
param workspaceName string = 'sentinel-rg-prod'

// Load KQL files for prod environment
var kqlcustomrule1 = loadTextContent('../kql/prod/customrule1.kql')
var kqlcustomrule2 = loadTextContent('../kql/prod/customrule2.kql')var rules = [
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
  }
]
// Deploy rules using the main module
module sentinelRules '../../../infra/sentinel-rules.bicep' = {
  name: 'sentinel-rules-prod'
  params: {
    workspaceName: workspaceName
    rules: rules
  }
}

// Outputs
output deployedRules array = sentinelRules.outputs.deployedRules


