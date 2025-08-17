// Generated rule configuration for test-auto-rule (dev)
// KQL loading line:
var kqltestautorule = loadTextContent('../kql/example-detection.kql')

// Rule object:
  {
    name: 'test-auto-rule'
    displayName: '[DEV] [ORG] – Test Auto Rule'
    kql: kqltestautorule
    severity: 'Medium'
    enabled: true
    frequency: 'PT1H'
    period: 'PT1H'
    tactics: [ 'InitialAccess'
    techniques: [ 'T1078'
    createIncident: false
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
      WorkstationName: 'WorkstationName'
      LogonType: 'LogonType'
    }
  }
