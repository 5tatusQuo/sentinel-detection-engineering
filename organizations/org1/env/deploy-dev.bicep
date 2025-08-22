// Dev environment wrapper - loads KQL files and configures rules
@description('Log Analytics workspace name (Sentinel-enabled)')
param workspaceName string = 'sentinel-rg-dev'

// Load KQL files
var kqltest1 = loadTextContent('../kql/dev/test1.kql')
var kqltest2 = loadTextContent('../kql/dev/test2.kql')
var kqltest3 = loadTextContent('../kql/dev/test3.kql')
var kqltest4 = loadTextContent('../kql/dev/test4.kql')
var kqltest5 = loadTextContent('../kql/dev/test5.kql')

// Define rules for dev environment
var rules = [
  {
    name: 'test1'
    displayName: '[DEV] [ORG] – Test1'
    kql: kqltest1
    severity: 'Low'
    enabled: true
    frequency: 'PT2H'
    period: 'PT2H'
    tactics: [ 'InitialAccess' ]
    techniques: [ 'T1078' ]
    createIncident: true
    grouping: {
      enabled: true
      matchingMethod: 'AllEntities'
    }
    entities: {
      hostName: 'Computer'
      accountFullName: 'SubjectUserName'
    }
    customDetails: {
      // TODO: Sync customDetails if needed
    }
  }, {
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
      // TODO: Sync customDetails if needed
    }
  }, {
    name: 'test3'
    displayName: '[DEV] [ORG] – Test3'
    kql: kqltest3
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
      // TODO: Sync customDetails if needed
    }
  }, {
    name: 'test4'
    displayName: '[DEV] [ORG] – Test4'
    kql: kqltest4
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
      // TODO: Sync customDetails if needed
    }
  }, {
    name: 'test5'
    displayName: '[DEV] [ORG] – Test5'
    kql: kqltest5
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
      // TODO: Sync customDetails if needed
    }
  },
  {
    name: 'customrule1'
    displayName: 'CustomRule1'
    kql: kqlcustomrule1
    severity: 'Medium'
    enabled: true
    frequency: 'PT5M'
    period: 'PT5M'
    tactics: [ 'InitialAccess' ]
    techniques: [  ]
    createIncident: true
    grouping: {
      enabled: false
      matchingMethod: 'AllEntities'
    }
    entities: {
      accountFullName: 'Caller'
    }
    customDetails: {
      // TODO: Sync customDetails if needed
    }
  }
]
