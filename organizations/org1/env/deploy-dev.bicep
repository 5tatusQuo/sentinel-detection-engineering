// Dev environment wrapper - loads KQL files and configures rules
@description('Log Analytics workspace name (Sentinel-enabled)')
param workspaceName string = 'sentinel-rg-dev'

// Load KQL files
// KQL variables will be populated by sync script

// Define rules for dev environment
var rules = [
  // Rules will be populated by sync script
]
