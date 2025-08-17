// Prod environment wrapper - reads rules from JSON configuration
@description('Log Analytics workspace name (Sentinel-enabled)')
param workspaceName string = 'sentinel-rg-prod'

// Load rules configuration from JSON file
var rulesConfig = loadJsonContent('./rules/prod-rules.json')

// Process rules: load KQL files and prepare for deployment
var processedRules = [for rule in rulesConfig.rules: {
  name: rule.name
  displayName: rule.displayName
  kql: loadTextContent('../kql/${rule.kqlFile}')
  severity: rule.severity
  enabled: rule.enabled
  frequency: rule.frequency
  period: rule.period
  tactics: rule.tactics
  techniques: rule.techniques
  createIncident: rule.createIncident
  grouping: rule.grouping
  entities: rule.entities
  customDetails: rule.customDetails
}]

// Deploy using the main template
module sentinelRules '../infra/sentinel-rules.bicep' = {
  name: 'sentinel-rules-prod'
  params: {
    workspaceName: workspaceName
    rules: processedRules
  }
}

// Outputs
output deployedRules array = sentinelRules.outputs.deployedRules
