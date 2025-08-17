// Generated rule configuration for test2 (dev)
// KQL loading line:
var kqltest2 = loadTextContent('../kql/test2.kql')

// Rule object:
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
