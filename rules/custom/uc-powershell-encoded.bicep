@description('Upstream lineage (optional)')
var x_metadata = {
  upstreamTemplateGuid: ''
  upstreamTemplateVersion: ''
  owner: 'Detection Engineering'
}

@description('Reference to the Log Analytics workspace')
param workspace resource

@description('The name that will appear in the Sentinel portal')
param ruleName string = '[ORG] – Suspicious PowerShell (EncodedCommand)'

@description('How serious is this threat?')
@allowed([
  'Critical'
  'High'
  'Medium'
  'Low'
  'Informational'
])
param severity string = 'Medium'

@description('Should this rule be turned on?')
param enabled bool = true

@description('The KQL query that detects encoded PowerShell')
param query string = '''
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

@description('Which MITRE ATT&CK tactics does this detect?')
param tactics array = [
  'Execution'
  'DefenseEvasion'
]

@description('Which specific MITRE ATT&CK techniques does this detect?')
param techniques array = [
  'T1059.001'
]

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

@description('Fields to group by (comma-separated)')
param groupByFields string = 'Computer,SubjectUserName'

resource sentinelRule 'Microsoft.SecurityInsights/alertRules@2025-06-01' = {
  parent: workspace
  name: guid(workspace.id, ruleName)
  kind: 'Scheduled'
  properties: {
    displayName: ruleName
    description: 'Detects PowerShell commands that use encoded commands, which is a common technique used by attackers to obfuscate malicious PowerShell code and evade detection.'
    enabled: enabled
    severity: severity
    query: query
    queryFrequency: 'PT1H'
    queryPeriod: 'PT1H'
    triggerOperator: 'GreaterThan'
    triggerThreshold: 0
    tactics: tactics
    techniques: techniques
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
        entityType: 'Host'
        fieldMappings: [
          {
            identifier: 'FullName'
            columnName: 'Computer'
          }
        ]
      }
      {
        entityType: 'Account'
        fieldMappings: [
          {
            identifier: 'Name'
            columnName: 'SubjectUserName'
          }
        ]
      }
    ]
    alertDetailsOverride: {
      alertDisplayNameFormat: 'Suspicious PowerShell Encoded Command Detected'
      alertDescriptionFormat: 'A suspicious PowerShell encoded command was detected on {Computer} by user {SubjectUserName}.'
    }
    customDetails: {
      EncodedCommand: 'EncodedCommand'
      DecodedCommand: 'DecodedCommand'
    }
  }
}
