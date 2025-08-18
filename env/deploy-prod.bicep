// Prod environment wrapper - loads KQL files and configures rules
@description('Log Analytics workspace name (Sentinel-enabled)')
param workspaceName string = 'sentinel-rg-prod'

// Load KQL files
var kqlEncoded = loadTextContent('../kql/uc-powershell-encoded.kql')
var kqlLogin = loadTextContent('../kql/suspicious-login-attempts.kql')
var kqlAdmin = loadTextContent('../kql/admin-account-anomaly.kql')
var kqltest1 = loadTextContent('../kql/test1.kql')
var kqltest2 = loadTextContent('../kql/test2.kql')
var kqltest4 = loadTextContent('../kql/test4.kql')
var kqltest5 = loadTextContent('../kql/test5.kql')

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
    name: 'admin-account-anomaly'
    displayName: '[PROD] [ORG] – Admin Account Anomaly Detection'
    kql: kqlAdmin
    severity: 'High'
    enabled: true
    frequency: 'PT1H'
    period: 'PT1H'
    tactics: [ 'DefenseEvasion', 'Persistence', 'PrivilegeEscalation' ]
    techniques: [ 'T1078' ]
    createIncident: true 
    grouping: {
      enabled: true
      matchingMethod: 'Selected'
    }
    entities: {}
    customDetails: {
      // TODO: Sync customDetails if needed
    }
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
      ipAddress: 'IpAddress'
      accountFullName: 'SubjectUserName'
      hostName: 'Computer'
    }
    customDetails: {
      LogonType: 'LogonType'
    }
  }
  {
    name: 'test2'
    displayName: '[PROD] [ORG] – Test2'
    kql: kqltest2
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
      ipAddress: 'IpAddress'
      accountFullName: 'SubjectUserName'
      hostName: 'Computer'
    }
    customDetails: {
      LogonType: 'LogonType'
    }
  }
  {
    name: 'test4'
    displayName: '[PROD] [ORG] – Test4'
    kql: kqltest4
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
      ipAddress: 'IpAddress'
      hostName: 'Computer'
      accountFullName: 'SubjectUserName'
    }
    customDetails: {
      LogonType: 'LogonType'
    }
  }
  {
    name: 'test5'
    displayName: '[PROD] [ORG] – Test5'
    kql: kqltest5
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
      ipAddress: 'IpAddress'
      hostName: 'Computer'
      accountFullName: 'SubjectUserName'
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

