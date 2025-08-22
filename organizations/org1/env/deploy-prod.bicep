// Prod environment - loads rules from JSON with static KQL file references
// KQL files are loaded based on rule names using naming convention

// Load KQL files based on naming convention
var kqlcustomrule1 = loadTextContent('../kql/prod/customrule1.kql')
var kqlcustomrule2 = loadTextContent('../kql/prod/customrule2.kql')
var kqlcustomrule3 = loadTextContent('../kql/prod/customrule3.kql')

// KQL lookup table for dynamic access
var kqlLookup = {
  'customrule1.kql': kqlcustomrule1
  'customrule2.kql': kqlcustomrule2
  'customrule3.kql': kqlcustomrule3
}

@description('Log Analytics workspace name (Sentinel-enabled)')
param workspaceName string = 'sentinel-rg-prod'

// Load rules configuration from JSON file
var rulesConfig = loadJsonContent('rules-prod.json')

// Transform JSON rules to Bicep format with KQL content
var rules = [for rule in rulesConfig: {
  name: rule.name
  displayName: rule.displayName
  kql: kqlLookup[rule.kqlFile]
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
