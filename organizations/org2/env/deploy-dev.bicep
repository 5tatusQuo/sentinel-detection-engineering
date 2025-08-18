// Dev environment wrapper for org2 - loads KQL files and configures rules
@description('Log Analytics workspace name (Sentinel-enabled)')
param workspaceName string = 'sentinel-rg-dev'

// Load KQL files
var kqlExample = loadTextContent('./kql/dev/example-rule.kql')

// Define rules for dev environment
var rules = [
  {
    name: 'example-rule'
    displayName: '[DEV] [ORG2] – Example Detection Rule'
    kql: kqlExample
    severity: 'Low'
    enabled: true
    frequency: 'PT1H'
    period: 'PT1H'
    tactics: [ 'InitialAccess' ]
    techniques: [ 'T1078' ]
    createIncident: false
    grouping: {
      enabled: true
      matchingMethod: 'AllEntities'
    }
    entities: {
      accountFullName: 'Account'
      hostName: 'Computer'
      ipAddress: 'IPAddress'
    }
    customDetails: {}
  }
]

// Deploy rules using the main module
module sentinelRules 'infra/sentinel-rules.bicep' = {
  name: 'sentinel-rules-dev'
  params: {
    workspaceName: workspaceName
    rules: rules
  }
}
