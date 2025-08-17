// Generated rule configuration for test5 (dev)
// KQL loading line:
var kqltest5 = loadTextContent('../kql/test5.kql')

// Rule object:
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
    createIncident: false
    grouping: {
      enabled: true
      matchingMethod: 'AllEntities'
    }
    entities: {
      accountFullName: 'SubjectUserName'
      ipAddress: 'IpAddress'
      hostName: 'Computer'
    }
    customDetails: {
      LogonType: 'LogonType'
    }
  }
