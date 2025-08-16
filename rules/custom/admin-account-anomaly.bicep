// =============================================================================
// ADMIN ACCOUNT ANOMALY DETECTION
// =============================================================================
// Detects unusual admin account activity patterns
// This rule helps identify potential privilege escalation or account compromise

// =============================================================================
// STEP 1: METADATA
// =============================================================================
@description('Information about this rule')
var ruleMetadata = {
  upstreamTemplateGuid: ''
  upstreamTemplateVersion: ''
  owner: 'Detection Engineering'
  description: 'Detects unusual admin account activity patterns'
}

// =============================================================================
// STEP 2: PARAMETERS
// =============================================================================
@description('The name that will appear in the Sentinel portal')
param ruleDisplayName string = '[ORG] – Admin Account Anomaly Detection (T1078)'

@description('How serious is this threat?')
@allowed([
  'Critical'
  'High'
  'Medium'
  'Low'
  'Informational'
])
param ruleSeverity string = 'High'

@description('Should this rule be turned on?')
param ruleEnabled bool = true

@description('How many admin logins before we alert?')
param adminLoginThreshold int = 3

@description('How often should we check?')
param queryFrequency string = 'PT1H'

@description('How far back should we look?')
param queryPeriod string = 'PT1H'

// =============================================================================
// STEP 3: THE DETECTION QUERY
// =============================================================================
@description('The KQL query that detects admin account anomalies')
param detectionQuery string = '''
// Look for admin account activity
SigninLogs
| where TimeGenerated >= ago(1h)
| where UserPrincipalName contains "admin" or UserPrincipalName contains "administrator"
| where ResultType == "0"  // Successful logins
| summarize 
    LoginCount = count(),
    LastLogin = max(TimeGenerated),
    FirstLogin = min(TimeGenerated),
    Applications = make_list(AppDisplayName),
    IPAddresses = make_list(IPAddress),
    Locations = make_list(Location)
    by UserPrincipalName
| where LoginCount >= ${adminLoginThreshold}
| extend TimeSpan = LastLogin - FirstLogin
| where TimeSpan < 30m  // Multiple logins within 30 minutes
| project 
    TimeGenerated = LastLogin,
    UserPrincipalName,
    LoginCount,
    TimeSpan,
    Applications,
    IPAddresses,
    Locations
'''

// =============================================================================
// STEP 4: ATTACK FRAMEWORK MAPPING
// =============================================================================
@description('Which MITRE ATT&CK tactics does this detect?')
param attackTactics array = [
  'Initial Access'
  'Privilege Escalation'
  'Persistence'
]

@description('Which specific MITRE ATT&CK techniques does this detect?')
param attackTechniques array = [
  'T1078'  // Valid Accounts
  'T1068'  // Exploitation for Privilege Escalation
]

// =============================================================================
// STEP 5: INCIDENT SETTINGS
// =============================================================================
@description('Should this create an incident when triggered?')
param createIncident bool = true

@description('Should we group similar alerts together?')
param groupAlerts bool = true

@description('How should we group alerts?')
@allowed([
  'SingleAlert'
  'GroupByAlertDetails'
  'GroupByCustomDetails'
  'GroupByEntities'
])
param groupingMethod string = 'GroupByAlertDetails'

@description('Which fields should we group by?')
param groupByFields string = 'UserPrincipalName'

// =============================================================================
// STEP 6: THE ACTUAL RULE
// =============================================================================
resource sentinelRule 'Microsoft.SecurityInsights/alertRules@2025-06-01' = {
  name: guid(resourceGroup().id, ruleDisplayName)
  location: resourceGroup().location
  kind: 'Scheduled'
  
  properties: {
    displayName: ruleDisplayName
    description: 'Detects unusual patterns of admin account usage, which could indicate privilege escalation, account compromise, or unauthorized administrative access.'
    enabled: ruleEnabled
    severity: ruleSeverity
    
    query: detectionQuery
    queryFrequency: queryFrequency
    queryPeriod: queryPeriod
    
    triggerOperator: 'GreaterThan'
    triggerThreshold: 0
    
    tactics: attackTactics
    techniques: attackTechniques
    
    incidentConfiguration: {
      createIncident: createIncident
      groupingConfiguration: {
        enabled: groupAlerts
        lookbackDuration: 'PT10M'
        matchingMethod: groupingMethod
        groupByEntities: groupByFields != '' ? split(groupByFields, ',') : []
        reopenClosedIncident: false
      }
    }
    
    entityMappings: [
      {
        entityType: 'Account'
        fieldMappings: [
          {
            identifier: 'Name'
            columnName: 'UserPrincipalName'
          }
        ]
      }
      {
        entityType: 'IP'
        fieldMappings: [
          {
            identifier: 'Address'
            columnName: 'IPAddresses'
          }
        ]
      }
    ]
    
    alertDetailsOverride: {
      alertDisplayNameFormat: 'Admin Account Anomaly: {UserPrincipalName}'
      alertDescriptionFormat: 'Unusual admin account activity detected for {UserPrincipalName} with {LoginCount} logins in {TimeSpan}.'
    }
    
    customDetails: {
      LoginCount: 'LoginCount'
      TimeSpan: 'TimeSpan'
      Applications: 'Applications'
      IPAddresses: 'IPAddresses'
      Locations: 'Locations'
    }
  }
}

// =============================================================================
// STEP 7: OUTPUTS
// =============================================================================
output ruleName string = sentinelRule.name
output ruleDisplayName string = sentinelRule.properties.displayName
output ruleEnabled bool = sentinelRule.properties.enabled
