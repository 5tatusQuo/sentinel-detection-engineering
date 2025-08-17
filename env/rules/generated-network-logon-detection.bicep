// Generated rule configuration for network-logon-detection
// Add this KQL loading line to your Bicep file:
var kqlnetworklogondetection = loadTextContent('../kql/example-detection.kql')

// Add this rule object to your rules array:
  {
    name: 'network-logon-detection'
    displayName: '[DEV] [ORG] – Network Logon Detection'
    kql: kqlnetworklogondetection
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
