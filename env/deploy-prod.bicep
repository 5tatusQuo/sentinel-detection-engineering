// Prod environment wrapper - loads KQL files and configures rules
@description('Log Analytics workspace name (Sentinel-enabled)')
param workspaceName string = 'sentinel-rg-prod'

// Load KQL files
var kqlEncoded = loadTextContent('../kql/uc-powershell-encoded.kql')
var kqlLogin = loadTextContent('../kql/suspicious-login-attempts.kql')
var kqlAdmin = loadTextContent('../kql/admin-account-anomaly.kql')
var kqltest1 = loadTextContent('../kql/test1.kql')

// Define rules for prod environment (higher thresholds, create incidents)
var rules = [
  {
    name: 'uc-powershell-encoded'
    displayName: '[PROD] [ORG] – Suspicious PowerShell (EncodedCommand)'
    kql: kqlEncoded
    severity: 'Medium'
    enabled: true
    frequency: 'PT1H'
    period: 'PT1H'
    tactics: [ 'Execution', 'DefenseEvasion' ]
    techniques: [ 'T1059' ]
    createIncident: true
    grouping: {
      enabled: true
      matchingMethod: 'AllEntities'
    }
    entities: {
      accountFullName: 'SubjectUserName'
      hostName: 'Computer'
    }
    customDetails: {
      EncodedArgument: 'EncArg'
      CommandLine: 'CommandLine'
    }
  }
  {
    name: 'uc-suspicious-login'
    displayName: '[PROD] [ORG] – Suspicious Login Attempts'
    kql: kqlLogin
    severity: 'Medium'
    enabled: true
    frequency: 'PT1H'
    period: 'PT1H'
    tactics: [ 'InitialAccess' ]
    techniques: [ 'T1078' ]
    createIncident: true
    grouping: {
      enabled: true
      matchingMethod: 'AllEntities'
    }
    entities: {
      ipAddress: 'IPAddress'
    }
    customDetails: {}
  }
  {
    name: 'uc-admin-anomaly'
    displayName: '[PROD] [ORG] – Admin Account Anomaly Detection'
    kql: kqlAdmin
    severity: 'High'
    enabled: true
    frequency: 'PT1H'
    period: 'PT1H'
    tactics: [ 'Persistence', 'PrivilegeEscalation', 'DefenseEvasion' ]
    techniques: [ 'T1078' ]
    createIncident: true
    grouping: {
      enabled: true
      matchingMethod: 'AllEntities'
    }
    entities: {
      accountFullName: 'UserPrincipalName'
    }
    customDetails: {}
  }
  {
    name: 'test1'
    displayName: '[PROD] [ORG] – Test1'
    kql: kqltest1
    severity: 'Medium'
    enabled: true
    frequency: 'PT1H'
    period: 'PT1H'
    tactics: [ 'InitialAccess' ]
    techniques: [ 'T1078' ]
    createIncident: true
    grouping: {
      enabled: true
      matchingMethod: 'AllEntities'
    }
    entities: {
      hostName: 'Computer'
      accountFullName: 'SubjectUserName'
      ipAddress: 'IPAddress'
    }
    customDetails: {
      LogonType: 'LogonType'
    }
  }
]

// Deploy using the main template
module sentinelRules '../infra/sentinel-rules.bicep' = {
  name: 'sentinel-rules-prod'
  params: {
    workspaceName: workspaceName
    rules: rules
  }
}

// Outputs
output deployedRules array = sentinelRules.outputs.deployedRules
