// Generated rule configuration for test-fixed-rule (dev)
// 
// STEP 1: Add this KQL loading line to env/deploy-dev.bicep
// (add it after the existing KQL loading lines)
//
var kqltestfixedrule = loadTextContent('../kql/example-detection.kql')
//
// STEP 2: Add this rule object to the rules array in env/deploy-dev.bicep
// (add it before the closing bracket of the rules array)
//
  {
    name: 'test-fixed-rule'
    displayName: '[DEV] [ORG] – Test Fixed Rule'
    kql: kqltestfixedrule
    severity: 'Medium'
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
      ipAddress: 'SourceIP'
      accountFullName: 'SubjectUserName'
    }
    customDetails: {
      WorkstationName: 'WorkstationName'
      LogonType: 'LogonType'
    }
  }
//
// STEP 3: Test your Bicep file
// az bicep build --file env/deploy-dev.bicep
