// Prod environment wrapper for org2 - loads KQL files and configures rules
@description('Log Analytics workspace name (Sentinel-enabled)')
param workspaceName string = 'sentinel-rg-prod'

// Define rules for prod environment (higher thresholds, create incidents)
var rules = [
  // Rules will be populated by sync script
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
