// Generated rule configuration for test-simple-rule (dev)
// 
// STEP 1: Add this KQL loading line to env/deploy-dev.bicep
// (add it after the existing KQL loading lines)
//
var kqltestsimplerule = loadTextContent('../kql/example-detection.kql')
//
// STEP 2: Add this rule object to the rules array in env/deploy-dev.bicep
// (add it before the closing bracket of the rules array)
//
  {
    name: 'test-simple-rule'
    displayName: '[DEV] [ORG] – Test Simple Rule'
    kql: kqltestsimplerule
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
      LogonType: 'LogonType'
      WorkstationName: 'WorkstationName'
    }
  }
//
// STEP 3: Test your Bicep file
// az bicep build --file env/deploy-dev.bicep
