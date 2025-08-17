// Generated rule configuration for test3 (prod)
// KQL loading line:
var kqltest3 = loadTextContent('../kql/test3.kql')

// Rule object:
  {
    name: 'test3'
    displayName: '[PROD] [ORG] – Test3'
    kql: kqltest3
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
      accountFullName: 'SubjectUserName'
      hostName: 'Computer'
      ipAddress: 'IpAddress'
    }
    customDetails: {
      LogonType: 'LogonType'
    }
  }
