// Generated rule configuration for test4 (dev)
// KQL loading line:
var kqltest4 = loadTextContent('../kql/test4.kql')

// Rule object:
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
    createIncident: false
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
