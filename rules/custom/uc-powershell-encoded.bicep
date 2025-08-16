@description('Upstream lineage (optional)')
var x_metadata = {
  upstreamTemplateGuid: ''
  upstreamTemplateVersion: ''
  owner: 'Detection Engineering'
}

@description('Rule display name override (optional)')
param ruleName string = '[ORG] – Suspicious PowerShell (EncodedCommand)'

@description('Rule severity')
@allowed([
  'Critical'
  'High'
  'Medium'
  'Low'
  'Informational'
])
param severity string = 'Medium'

@description('Enable or disable the rule')
param enabled bool = true

@description('Detection query')
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

@description('MITRE ATT&CK tactics')
param tactics array = [
  'Execution'
  'DefenseEvasion'
]

@description('MITRE ATT&CK techniques')
param techniques array = [
  'T1059.001'
]

@description('Create incidents for alerts')
param createIncident bool = true

@description('Group alerts into incidents')
param groupAlerts bool = true

@description('Incident grouping method')
@allowed([
  'SingleAlert'
  'GroupByAlertDetails'
  'GroupByCustomDetails'
  'GroupByEntities'
])
param groupingMethod string = 'GroupByAlertDetails'

@description('Group by fields (comma-separated)')
param groupByFields string = 'Computer,SubjectUserName'

resource sentinelRule 'Microsoft.SecurityInsights/alertRules@2025-06-01' = {
  parent: resourceGroup()
  name: guid(resourceGroup().id, ruleName)
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
