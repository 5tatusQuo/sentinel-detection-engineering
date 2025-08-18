// Dev environment wrapper - loads KQL files and configures rules
@description('Log Analytics workspace name (Sentinel-enabled)')
param workspaceName string = 'sentinel-rg-dev'

// Load KQL files
var kqladminaccountanomalydetectiont1078 = loadTextContent('./kql/dev/admin-account-anomaly-detection-(t1078).kql')
var kqladminaccountanomalydetection = loadTextContent('./kql/dev/admin-account-anomaly-detection.kql')
var kqlsuspiciousloginattemptst1078 = loadTextContent('./kql/dev/suspicious-login-attempts-(t1078).kql')
var kqlsuspiciousloginattempts = loadTextContent('./kql/dev/suspicious-login-attempts.kql')
var kqlsuspiciouspowershellencodedcommand = loadTextContent('./kql/dev/suspicious-powershell-(encodedcommand).kql')
var kqltestautomatedrule = loadTextContent('./kql/dev/test-automated-rule.kql')
var kqltest1 = loadTextContent('./kql/dev/test1.kql')
var kqltest2 = loadTextContent('./kql/dev/test2.kql')
var kqltest3 = loadTextContent('./kql/dev/test3.kql')
var kqltest4 = loadTextContent('./kql/dev/test4.kql')
var kqltest5 = loadTextContent('./kql/dev/test5.kql')

// Define rules for dev environment
var rules = [
  // Rules will be populated by sync script
  {
    name: 'admin-account-anomaly-detection'
    displayName: '[DEV] [ORG] – Admin Account Anomaly Detection'
    kql: kqladminaccountanomalydetection
    severity: 'Medium'
    enabled: true
    frequency: 'PT1H'
    period: 'PT1H'
    tactics: [ 'DefenseEvasion', 'Persistence', 'PrivilegeEscalation' ]
    techniques: [ 'T1078' ]
    createIncident: true
    grouping: {
      enabled: true
      matchingMethod: 'AllEntities'
    }
    entities: {
      accountFullName: 'UserPrincipalName'
    }
    customDetails: {
      // TODO: Sync customDetails if needed
    }
  }
  {
    name: 'suspicious-login-attempts'
    displayName: '[DEV] [ORG] – Suspicious Login Attempts'
    kql: kqlsuspiciousloginattempts
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
      ipAddress: 'IPAddress'
    }
    customDetails: {
      // TODO: Sync customDetails if needed
    }
  }
  {
    name: 'suspicious-powershell-(encodedcommand)'
    displayName: '[DEV] [ORG] – Suspicious PowerShell (EncodedCommand)'
    kql: kqlsuspiciouspowershellencodedcommand
    severity: 'Low'
    enabled: true
    frequency: 'PT1H'
    period: 'PT1H'
    tactics: [ 'DefenseEvasion', 'Execution' ]
    techniques: [ 'T1059' ]
    createIncident: true
    grouping: {
      enabled: true
      matchingMethod: 'AllEntities'
    }
    entities: {
      hostName: 'Computer'
      accountFullName: 'SubjectUserName'
    }
    customDetails: {
      // TODO: Sync customDetails if needed
    }
  },
  {
    name: 'test-automated-rule'
    displayName: '[DEV] [ORG] – Test Automated Rule'
    kql: kqltestautomatedrule
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
      ipAddress: 'SourceIP'
      hostName: 'Computer'
      accountFullName: 'SubjectUserName'
    }
    customDetails: {
      // TODO: Sync customDetails if needed
    }
  },
  {
    name: 'test1'
    displayName: '[DEV] [ORG] – Test1'
    kql: kqltest1
    severity: 'Low'
    enabled: true
    frequency: 'PT2H'
    period: 'PT2H'
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
    }
    customDetails: {
      // TODO: Sync customDetails if needed
    }
  },
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
      // TODO: Sync customDetails if needed
    }
  },
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
      // TODO: Sync customDetails if needed
    }
  },
  {
    name: 'test4'
    displayName: '[DEV] [ORG] – Test4'
    kql: kqltest4
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
      // TODO: Sync customDetails if needed
    }
  },
  {
    name: 'test5'
    displayName: '[DEV] [ORG] – Test5'
    kql: kqltest5
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
      // TODO: Sync customDetails if needed
    }
  }
]
