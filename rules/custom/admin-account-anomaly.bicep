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
// STEP 2: PARAMETERS (What can be customized)
// =============================================================================

// Basic rule settings
@description('Display name for the detection rule')
param ruleDisplayName string = '[ORG] – Admin Account Anomaly Detection (T1078)'

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
| where ResultType == 0  // Successful logins
| where UserPrincipalName has "@"  // Only cloud accounts
| where AppDisplayName in~ ("Microsoft Azure PowerShell", "Microsoft Azure CLI", "Azure Portal")
| summarize LoginCount = count(), 
          Applications = make_set(AppDisplayName),
          IPAddresses = make_set(IPAddress),
          Locations = make_set(Location),
          TimeSpan = max(TimeGenerated) - min(TimeGenerated)
    by UserPrincipalName, bin(TimeGenerated, 5m)
| where LoginCount >= 3  // Multiple logins in short time
| where TimeSpan < 30m   // Within 30 minutes
| project TimeGenerated, UserPrincipalName, LoginCount, Applications, IPAddresses, Locations, TimeSpan
'''

@description('How often to run the query')
param queryFrequency string = 'PT1H'

@description('Time window for the query')
param queryPeriod string = 'PT1H'

// ATT&CK mapping
@description('MITRE ATT&CK tactics')
param attackTactics array = [
  'Persistence'
  'PrivilegeEscalation'
  'DefenseEvasion'
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

@description('Fields to group by (comma-separated)')
param groupByFields string = 'UserPrincipalName'

// Workspace parameter
@description('Name of the Log Analytics workspace')
param workspaceName string

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
resource sentinelRule 'Microsoft.OperationalInsights/workspaces/providers/Microsoft.SecurityInsights/alertRules@2025-06-01' = {
  name: '${workspaceName}/Microsoft.SecurityInsights/${guid(resourceGroup().id, ruleDisplayName)}'
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
