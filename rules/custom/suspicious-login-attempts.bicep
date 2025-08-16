// =============================================================================
// SUSPICIOUS LOGIN ATTEMPTS DETECTION
// =============================================================================
// Detects multiple failed login attempts from the same IP address
// This rule helps identify brute force attacks and credential stuffing

// =============================================================================
// STEP 1: PARAMETERS (What can be customized)
// =============================================================================

// Workspace reference
@description('Reference to the Log Analytics workspace')
param workspace resource

// Basic rule settings
@description('Display name for the detection rule')
param ruleDisplayName string = '[ORG] – Suspicious Login Attempts (T1078)'

@description('Whether the rule is enabled')
param ruleEnabled bool = true

@description('Severity level of the alert')
@allowed(['Low', 'Medium', 'High', 'Critical'])
param ruleSeverity string = 'Medium'

// Detection query settings
@description('KQL query for detection logic')
param detectionQuery string = '''
SigninLogs
| where TimeGenerated > ago(1h)
| where ResultType != 0  // Failed logins
| summarize FailedAttempts = count() by IPAddress, AppDisplayName, bin(TimeGenerated, 5m)
| where FailedAttempts >= 5  // Multiple failed attempts
| project TimeGenerated, IPAddress, AppDisplayName, FailedAttempts
'''

@description('How often to run the query')
param queryFrequency string = 'PT1H'

@description('Time window for the query')
param queryPeriod string = 'PT1H'

// ATT&CK mapping
@description('MITRE ATT&CK tactics')
param attackTactics array = [
  'InitialAccess'
  'Persistence'
]

@description('MITRE ATT&CK techniques')
param attackTechniques array = [
  'T1078'  // Valid Accounts
]

// Incident configuration
@description('Whether to create incidents from alerts')
param createIncident bool = true

@description('Whether to group related alerts')
param groupAlerts bool = true

@description('How to group alerts')
@allowed(['AllEntities', 'Custom', 'None'])
param groupingMethod string = 'AllEntities'

// Fields to group by (comma-separated)
@description('Fields to group by (comma-separated)')
param groupByFields string = 'IPAddress'

// =============================================================================
// STEP 2: THE ACTUAL RULE
// =============================================================================
resource sentinelRule 'Microsoft.SecurityInsights/alertRules@2025-06-01' = {
  parent: workspace
  name: guid(workspace.id, ruleDisplayName)
  kind: 'Scheduled'
  
  properties: {
    displayName: ruleDisplayName
    description: 'Detects multiple failed login attempts from the same IP address, which could indicate a brute force attack or credential stuffing attempt.'
    enabled: ruleEnabled
    severity: ruleSeverity
    
    query: detectionQuery
    queryFrequency: queryFrequency
    queryPeriod: queryPeriod
    
    triggerOperator: 'GreaterThan'
    triggerThreshold: 0
    
    tactics: attackTactics
    techniques: attackTechniques
    
    suppressionEnabled: false
    suppressionDuration: 'PT0H'
    
    incidentConfiguration: {
      createIncident: createIncident
      groupingConfiguration: {
        enabled: groupAlerts
        lookbackDuration: 'PT5M'
        matchingMethod: groupingMethod
        groupByEntities: groupByFields != '' ? split(groupByFields, ',') : []
        reopenClosedIncident: false
      }
    }
    
    entityMappings: [
      {
        entityType: 'IP'
        fieldMappings: [
          {
            identifier: 'Address'
            columnName: 'IPAddress'
          }
        ]
      }
      {
        entityType: 'Account'
        fieldMappings: [
          {
            identifier: 'Name'
            columnName: 'UserNames'
          }
        ]
      }
    ]
    
    alertDetailsOverride: {
      alertDisplayNameFormat: 'Suspicious Login Attempts Detected from {IPAddress}'
      alertDescriptionFormat: 'Multiple failed login attempts ({FailedAttempts}) detected from IP address {IPAddress} to application {AppDisplayName}.'
    }
    
    customDetails: {
      FailedAttempts: 'FailedAttempts'
      AppDisplayName: 'AppDisplayName'
      UserNames: 'UserNames'
    }
  }
}

// =============================================================================
// STEP 3: OUTPUTS
// =============================================================================
output ruleName string = sentinelRule.name
output ruleDisplayName string = sentinelRule.properties.displayName
output ruleEnabled bool = sentinelRule.properties.enabled
