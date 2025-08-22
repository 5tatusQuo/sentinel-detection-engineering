// Prod environment wrapper for org2 - loads KQL files and configures rules
@description('Log Analytics workspace name (Sentinel-enabled)')
param workspaceName string = 'sentinel-rg-prod'

// Load KQL files
// Define rules for prod environment (higher thresholds, create incidents)
var rules = [
  
    entities: {
      accountFullName: 'Account'
      hostName: 'Computer'
      ipAddress: 'IPAddress'
    }
    customDetails: {}
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

