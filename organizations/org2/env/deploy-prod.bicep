// Prod environment wrapper for org2 - loads KQL files and configures rules
@description('Log Analytics workspace name (Sentinel-enabled)')
param workspaceName string = 'sentinel-rg-prod'

// Load KQL files
var kqlExample = loadTextContent('./kql/prod/example-rule.kql')

// Define rules for prod environment (higher thresholds, create incidents)
var rules = [
  {
    name: 'example-rule'
    displayName: '[PROD] [ORG2] – Example Detection Rule'
    kql: kqlExample
    severity: 'Medium'
    enabled: true
    frequency: 'PT1H'
    period: 'PT1H'
    tactics: [ 'InitialAccess' ]
    techniques: [ 'T1078' ]
    createIncident: true
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
  name: 'sentinel-rules-prod'
  params: {
    workspaceName: workspaceName
    rules: rules
  }
}
