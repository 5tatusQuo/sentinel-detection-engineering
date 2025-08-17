// Generated rule configuration for test1 (dev)
// KQL loading line:
var kqltest1 = loadTextContent('../kql/test1.kql')

// Rule object:
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
      ipAddress: 'IPAddress'
      accountFullName: 'SubjectUserName'
      hostName: 'Computer'
    }
    customDetails: {
      LogonType: 'LogonType'
    }
  }
