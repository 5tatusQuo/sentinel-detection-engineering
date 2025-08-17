// Generated rule configuration for test5 (prod)
// KQL loading line:
var kqltest5 = loadTextContent('../kql/test5.kql')

// Rule object:
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
