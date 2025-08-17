// Generated rule configuration for test1 (prod)
// KQL loading line:
var kqltest1 = loadTextContent('../kql/test1.kql')

// Rule object:
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
      accountFullName: 'SubjectUserName'
      ipAddress: 'IPAddress'
      hostName: 'Computer'
    }
    customDetails: {
      LogonType: 'LogonType'
    }
  }
