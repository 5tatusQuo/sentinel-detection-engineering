

@description('Name of the Log Analytics workspace')
param workspaceName string

@description('The name that will appear in the Sentinel portal')
param ruleDisplayName string = '[ORG] – Suspicious PowerShell (EncodedCommand)'

@description('Whether the rule is enabled')
param ruleEnabled bool = true

@description('How serious is this threat?')
@allowed([
  'Critical'
  'High'
  'Medium'
  'Low'
  'Informational'
])
param ruleSeverity string = 'Medium'

@description('The KQL query that detects encoded PowerShell')
param detectionQuery string = '''
SecurityEvent
| where EventID == 4104
| where EventData contains "EncodedCommand"
| where EventData contains "powershell"
| extend EncodedCommand = extract("EncodedCommand\\s*=\\s*([^\\s]+)", 1, EventData)
| where isnotempty(EncodedCommand)
| extend DecodedCommand = base64_decode_tostring(EncodedCommand)
| where DecodedCommand contains "Invoke-Expression" or DecodedCommand contains "IEX"
| project TimeGenerated, Computer, SubjectUserName, EncodedCommand, DecodedCommand
'''

@description('How often to run the query')
param queryFrequency string = 'PT1H'

@description('Time window for the query')
param queryPeriod string = 'PT1H'

@description('Which MITRE ATT&CK tactics does this detect?')
param attackTactics array = [
  'Execution'
  'DefenseEvasion'
]

@description('Which specific MITRE ATT&CK techniques does this detect?')
param attackTechniques array = [
  'T1059'
]

@description('Should this create an incident when triggered?')
param createIncident bool = true

@description('Should we group similar alerts together?')
param groupAlerts bool = true

@description('How should we group alerts?')
@allowed(['AllEntities', 'Custom', 'None'])
param groupingMethod string = 'AllEntities'



// Reference the existing Log Analytics workspace
resource la 'Microsoft.OperationalInsights/workspaces@2022-10-01' existing = {
  name: workspaceName
}

resource sentinelRule 'Microsoft.SecurityInsights/alertRules@2025-06-01' = {
  scope: la
  name: guid(la.id, ruleDisplayName)
  kind: 'Scheduled'
  properties: {
    displayName: ruleDisplayName
    description: 'Detects PowerShell commands that use encoded commands, which is a common technique used by attackers to obfuscate malicious PowerShell code and evade detection.'
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
    suppressionDuration: 'PT5M'
    incidentConfiguration: {
      createIncident: createIncident
      groupingConfiguration: {
        enabled: groupAlerts
        lookbackDuration: 'PT5M'
        matchingMethod: groupingMethod
        groupByEntities: ['Account', 'Host']
        reopenClosedIncident: false
      }
    }
    entityMappings: [
      {
        entityType: 'Account'
        fieldMappings: [
          {
            identifier: 'FullName'
            columnName: 'SubjectUserName'
          }
        ]
      }
      {
        entityType: 'Host'
        fieldMappings: [
          {
            identifier: 'HostName'
            columnName: 'Computer'
          }
        ]
      }
    ]
    alertDetailsOverride: {
      alertDisplayNameFormat: 'Suspicious PowerShell Encoded Command Detected'
      alertDescriptionFormat: 'A suspicious PowerShell command using encoded commands was detected on {Computer} by user {SubjectUserName}. This technique is commonly used by attackers to obfuscate malicious code.'
    }
    customDetails: {
      EncodedCommand: 'EncodedCommand'
      DecodedCommand: 'DecodedCommand'
    }
  }
}

output ruleName string = sentinelRule.properties.displayName
output workspaceName string = la.name
