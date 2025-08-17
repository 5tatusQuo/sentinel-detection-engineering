// Dev environment wrapper - loads KQL files and configures rules
@description('Log Analytics workspace name (Sentinel-enabled)')
param workspaceName string = 'sentinel-rg-dev'

// Load KQL files
var kqlEncoded = loadTextContent('../kql/uc-powershell-encoded.kql')
var kqlLogin = loadTextContent('../kql/suspicious-login-attempts.kql')
var kqlAdmin = loadTextContent('../kql/admin-account-anomaly.kql')
var kqltest1 = loadTextContent('../kql/test1.kql')
var kqltest2 = loadTextContent('../kql/test2.kql')
var kqltest3 = loadTextContent('../kql/test3.kql')

// Define rules for dev environment
var rules = [
  {
    name: 'uc-powershell-encoded'
    displayName: '[DEV] [ORG] – Suspicious PowerShell (EncodedCommand)'
    kql: kqlEncoded
    severity: 'Low'
    enabled: true
    frequency: 'PT1H'
    period: 'PT1H'
    tactics: [ 'Execution', 'DefenseEvasion' ]
    techniques: [ 'T1059' ]
    createIncident: false
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
    displayName: '[DEV] [ORG] – Suspicious Login Attempts'
    kql: kqlLogin
    severity: 'Low'
    enabled: true
    frequency: 'PT1H'
    period: 'PT1H'
    tactics: [ 'InitialAccess' ]
    techniques: [ 'T1078' ]
    createIncident: false
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
    displayName: '[DEV] [ORG] – Admin Account Anomaly Detection'
    kql: kqlAdmin
    severity: 'Medium'
    enabled: true
    frequency: 'PT1H'
    period: 'PT1H'
    tactics: [ 'Persistence', 'PrivilegeEscalation', 'DefenseEvasion' ]
    techniques: [ 'T1078' ]
    createIncident: false
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
    displayName: '[DEV] [ORG] – Test1'
    kql: kqltest1
    severity: 'Low'
    enabled: true
    frequency: 'PT1H'
    period: 'PT1H'
    tactics: [ 'InitialAccess' ]
    techniques: [ 'T1078' ]
    createIncident: false
    grouping: {
      enabled: true
      matchingMethod: 'AllEntities'
    }
    entities: {
      hostName: 'Computer'
      accountFullName: 'SubjectUserName'
      ipAddress: 'IpAddress'
    }
    customDetails: {
      LogonType: 'LogonType'
    }
  }
  {
    name: 'test2'
    displayName: '[DEV] [ORG] – Test2'
    kql: kqltest2
    severity: 'Low'
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
    name: 'test3'
    displayName: '[DEV] [ORG] – Test3'
    kql: kqltest3
    severity: 'Low'
    enabled: true
    frequency: 'PT1H'
    period: 'PT1H'
    tactics: [ 'InitialAccess' ]
    techniques: [ 'T1078' ]
    createIncident: false
    grouping: {
      enabled: true
      matchingMethod: 'AllEntities'
    }
    entities: {
      hostName: 'Computer'
      accountFullName: 'SubjectUserName'
      ipAddress: 'IpAddress'
    }
    customDetails: {
      LogonType: 'LogonType'
    }
  }
]

// Deploy using the main template
module sentinelRules '../infra/sentinel-rules.bicep' = {
  name: 'sentinel-rules-dev'
  params: {
    workspaceName: workspaceName
    rules: rules
  }
}

// Outputs
output deployedRules array = sentinelRules.outputs.deployedRules
