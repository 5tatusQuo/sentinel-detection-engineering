// Required
param name string
param displayName string
param kql string
param workspaceName string

// Optional with defaults
@allowed(['Critical','High','Medium','Low','Informational'])
param severity string = 'Medium'
param enabled bool = true
param frequency string = 'PT1H'
param period string = 'PT1H'
param createIncident bool = true

// ATT&CK (NOTE: techniques must be T#### at this API level)
param tactics array = []
param techniques array = []

// Advanced (partial objects allowed)
param grouping object = {}
param entities object = {}
param customDetails object = {}

// Merge caller objects with defaults
var groupingDefaults = {
  enabled: true
  matchingMethod: 'AllEntities'   // or 'Selected'
@description('Rule name (unique within workspace)')
param name string

@description('Display name of the rule')
param displayName string

@description('KQL query that defines detection logic')
param kql string

@allowed([ 'Low' 'Medium' 'High' 'Informational' ])
param severity string

@description('Enable or disable the rule')
param enabled bool = true

@description('Query frequency (ISO8601 duration, e.g. PT1H)')
param frequency string

@description('Query lookback period (ISO8601 duration)')
param period string

@description('MITRE ATT&CK tactics')
param tactics array

@description('MITRE ATT&CK techniques (only top-level T#### supported)')
param techniques array

@description('Whether to create incidents')
param createIncident bool = true

// ----- optional -----
@description('Custom grouping settings')
param grouping object = {}

@description('Entity mappings')
param entities array = []

@description('Custom details (key-value mapping)')
param customDetails object = {}
