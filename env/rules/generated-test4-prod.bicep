// Generated rule configuration for test4 (prod)
// KQL loading line:
var kqltest4 = loadTextContent('../kql/test4.kql')

// Rule object:
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
