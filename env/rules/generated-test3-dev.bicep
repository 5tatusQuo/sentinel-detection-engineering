// Generated rule configuration for test3 (dev)
// KQL loading line:
var kqltest3 = loadTextContent('../kql/test3.kql')

// Rule object:
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
