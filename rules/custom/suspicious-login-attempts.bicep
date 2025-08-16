// =============================================================================
// BEGINNER-FRIENDLY DETECTION RULE TEMPLATE
// =============================================================================
// This template shows how to create a simple detection rule step by step.
// Each section is clearly commented to help you understand what each part does.

// =============================================================================
// STEP 1: METADATA (Information about this rule)
// =============================================================================
@description('Information about where this rule came from and who owns it')
var ruleMetadata = {
  // If you copied this from a vendor rule, put the original rule ID here
  upstreamTemplateGuid: ''
  // If you copied this from a vendor rule, put the original version here  
  upstreamTemplateVersion: ''
  // Who is responsible for this rule
  owner: 'Detection Engineering'
  // What this rule detects (for documentation)
  description: 'Detects multiple failed login attempts from the same source'
}

// =============================================================================
// STEP 2: PARAMETERS (Values that can be changed per environment)
// =============================================================================
@description('The name that will appear in the Sentinel portal')
param ruleDisplayName string = '[ORG] – Suspicious Login Attempts (T1078)'

@description('How serious is this threat? (Critical, High, Medium, Low, Informational)')
@allowed([
  'Critical'
  'High'
  'Medium'
  'Low'
  'Informational'
])
param ruleSeverity string = 'Medium'

@description('Should this rule be turned on? (true = on, false = off)')
param ruleEnabled bool = true

@description('How many failed logins before we alert?')
param failedLoginThreshold int = 5

@description('How often should we check for this? (PT1H = every hour, PT15M = every 15 minutes)')
param queryFrequency string = 'PT1H'

@description('How far back should we look for failed logins?')
param queryPeriod string = 'PT1H'

// =============================================================================
// STEP 3: THE DETECTION QUERY (The KQL query that finds the bad stuff)
// =============================================================================
@description('The KQL query that detects the suspicious activity')
param detectionQuery string = '''
// Look for failed login attempts
SigninLogs
| where ResultType == "50126"  // Invalid username or password
| where TimeGenerated >= ago(1h)  // Look back 1 hour
| summarize 
    FailedAttempts = count(),
    LastAttempt = max(TimeGenerated),
    UserNames = make_list(UserPrincipalName),
    IPAddresses = make_list(IPAddress)
    by IPAddress, AppDisplayName
| where FailedAttempts >= ${failedLoginThreshold}  // Alert if threshold exceeded
| project 
    TimeGenerated = LastAttempt,
    IPAddress,
    AppDisplayName,
    FailedAttempts,
    UserNames,
    IPAddresses
'''

// =============================================================================
// STEP 4: ATTACK FRAMEWORK MAPPING (MITRE ATT&CK)
// =============================================================================
@description('Which MITRE ATT&CK tactics does this detect?')
param attackTactics array = [
  'Initial Access'    // Getting into the system
  'Persistence'       // Staying in the system
]

@description('Which specific MITRE ATT&CK techniques does this detect?')
param attackTechniques array = [
  'T1078'  // Valid Accounts
]

// =============================================================================
// STEP 5: INCIDENT SETTINGS (How to handle alerts)
// =============================================================================
@description('Should this create an incident when triggered?')
param createIncident bool = true

@description('Should we group similar alerts together?')
param groupAlerts bool = true

@description('How should we group alerts? (GroupByAlertDetails = group by similar alerts)')
@allowed([
  'SingleAlert'
  'GroupByAlertDetails'
  'GroupByCustomDetails'
  'GroupByEntities'
])
param groupingMethod string = 'GroupByAlertDetails'

@description('Which fields should we group by? (comma-separated)')
param groupByFields string = 'IPAddress,AppDisplayName'

// =============================================================================
// STEP 6: THE ACTUAL RULE (Putting it all together)
// =============================================================================
resource sentinelRule 'Microsoft.SecurityInsights/alertRules@2025-06-01' = {
  // Give the rule a unique name (this will be auto-generated)
  name: guid(resourceGroup().id, ruleDisplayName)
  
  // Where to deploy this rule
  location: resourceGroup().location
  
  // All the rule settings
  properties: {
    // Basic information
    displayName: ruleDisplayName
    description: 'Detects multiple failed login attempts from the same IP address, which could indicate a brute force attack or credential stuffing attempt.'
    enabled: ruleEnabled
    severity: ruleSeverity
    
    // The detection logic
    query: detectionQuery
    queryFrequency: queryFrequency
    queryPeriod: queryPeriod
    
    // When to trigger the alert
    triggerOperator: 'GreaterThan'
    triggerThreshold: 0
    
    // Attack framework mapping
    tactics: attackTactics
    techniques: attackTechniques
    
    // Incident creation settings
    incidentConfiguration: {
      createIncident: createIncident
      groupingConfiguration: {
        enabled: groupAlerts
        lookbackDuration: 'PT5M'  // Group alerts within 5 minutes
        matchingMethod: groupingMethod
        groupByEntities: groupByFields != '' ? split(groupByFields, ',') : []
        reopenClosedIncident: false
      }
    }
    
    // What entities to extract (for investigation)
    entityMappings: [
      {
        entityType: 'IP'  // Extract IP addresses as entities
        fieldMappings: [
          {
            identifier: 'Address'
            columnName: 'IPAddress'
          }
        ]
      }
      {
        entityType: 'Account'  // Extract usernames as entities
        fieldMappings: [
          {
            identifier: 'Name'
            columnName: 'UserNames'
          }
        ]
      }
    ]
    
    // Customize the alert details
    alertDetailsOverride: {
      alertDisplayNameFormat: 'Suspicious Login Attempts Detected from {IPAddress}'
      alertDescriptionFormat: 'Multiple failed login attempts ({FailedAttempts}) detected from IP address {IPAddress} to application {AppDisplayName}.'
    }
    
    // Add custom details for investigation
    customDetails: {
      'FailedAttempts': 'FailedAttempts'
      'AppDisplayName': 'AppDisplayName'
      'UserNames': 'UserNames'
    }
  }
}

// =============================================================================
// STEP 7: OUTPUTS (Optional - information returned after deployment)
// =============================================================================
output ruleName string = sentinelRule.name
output ruleDisplayName string = sentinelRule.properties.displayName
output ruleEnabled bool = sentinelRule.properties.enabled
