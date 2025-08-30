#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Detect drift between desired state (Bicep) and actual state (Sentinel).

.DESCRIPTION
    This script compares the desired state from Bicep templates with the actual
    state in the production Sentinel workspace and reports any differences.

.PARAMETER SubscriptionId
    Azure subscription ID (from environment variable SUBSCRIPTION_ID)

.PARAMETER ResourceGroup
    Resource group name (from environment variable RESOURCE_GROUP)

.PARAMETER Workspace
    Log Analytics workspace name (from environment variable WORKSPACE)

.PARAMETER ApiVersion
    API version to use (defaults to 2025-06-01)

.PARAMETER Organization
    Organization name (e.g., org1, org2) to determine Bicep file location

.EXAMPLE
    .\detect_drift.ps1
#>

param(
    [string]$SubscriptionId = $env:SUBSCRIPTION_ID,
    [string]$ResourceGroup = $env:RESOURCE_GROUP,
    [string]$Workspace = $env:WORKSPACE,
    [string]$ApiVersion = $env:API_VERSION,
    [string]$Organization = $env:ORGANIZATION
)

# Set default API version if not provided
if (-not $ApiVersion) {
    $ApiVersion = "2025-06-01"
}

# Validate required parameters
if (-not $Organization) {
    Write-Error "Organization parameter is required"
    exit 1
}

# Get subscription ID dynamically if not provided
if (-not $SubscriptionId) {
    try {
        $SubscriptionId = (az account show --query id -o tsv).Trim()
        if (-not $SubscriptionId) {
            throw "Could not get subscription ID from Azure CLI"
        }
        Write-Host "Got subscription ID dynamically: $SubscriptionId" -ForegroundColor Green
    }
    catch {
        Write-Error "Failed to get subscription ID: $_"
        Write-Error "Please ensure you're logged in with 'az login' or provide SUBSCRIPTION_ID environment variable"
        exit 1
    }
} else {
    Write-Host "Using provided subscription ID: $SubscriptionId" -ForegroundColor Green
}

# Use correct values from config if not provided
if (-not $ResourceGroup) {
    if ($Organization -eq "org1") {
        $ResourceGroup = "sentinel-ws-dev"  # From config/organizations.json
        Write-Host "Using resource group from config: $ResourceGroup" -ForegroundColor Green
    } else {
        Write-Error "RESOURCE_GROUP environment variable is required or Organization must be 'org1'"
        exit 1
    }
} else {
    Write-Host "Using provided resource group: $ResourceGroup" -ForegroundColor Green
}

if (-not $Workspace) {
    if ($Organization -eq "org1") {
        $Workspace = "sentinel-rg-dev"  # From config/organizations.json
        Write-Host "Using workspace from config: $Workspace" -ForegroundColor Green
    } else {
        Write-Error "WORKSPACE environment variable is required or Organization must be 'org1'"
        exit 1
    }
} else {
    Write-Host "Using provided workspace: $Workspace" -ForegroundColor Green
}

Write-Host "Detecting drift in workspace: $Workspace" -ForegroundColor Green

# Get access token using Azure CLI
try {
    $token = (az account get-access-token --resource=https://management.azure.com --query accessToken -o tsv).Trim()
    if (-not $token) {
        # For local testing without Azure auth, use dummy token
        if ($SubscriptionId -eq "dummy") {
            $token = "dummy-token"
            Write-Host "Using dummy token for local testing" -ForegroundColor Yellow
        } else {
            throw "Failed to obtain access token - token is empty"
        }
    }
    Write-Host "Successfully obtained access token" -ForegroundColor Green
}
catch {
    Write-Error "Failed to obtain access token: $_"
    exit 1
}

# Set headers for API calls
$headers = @{
    "Authorization" = "Bearer $token"
    "Content-Type" = "application/json"
}

# Build API URL
$baseUrl = "https://management.azure.com/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroup/providers/Microsoft.OperationalInsights/workspaces/$Workspace/providers/Microsoft.SecurityInsights/alertRules"
$url = "$baseUrl`?api-version=$ApiVersion"

$allRules = @()
$nextLink = $url

# Fetch all rules (handle pagination)
if ($SubscriptionId -eq "dummy") {
    # For local testing, use dummy rules
    Write-Host "Using dummy rules for local testing" -ForegroundColor Yellow
    $allRules = @(
        @{
            name = "customrule1"
            properties = @{
                displayName = "CustomRule1"
                enabled = $true
                severity = "Medium"
                query = "AzureActivity`n| take 10`n"
                tactics = @("InitialAccess")
                techniques = @()
                incidentConfiguration = @{
                    createIncident = $true
                    groupingConfiguration = @{ enabled = $false }
                }
            }
        },
        @{
            name = "customrule2"
            properties = @{
                displayName = "CustomRule2"
                enabled = $true
                severity = "Medium"
                query = "AzureActivity`n| take 11`n"
                tactics = @("InitialAccess")
                techniques = @()
                incidentConfiguration = @{
                    createIncident = $true
                    groupingConfiguration = @{ enabled = $false }
                }
            }
        },
        @{
            name = "customrule3"
            properties = @{
                displayName = "CustomRule3"
                enabled = $true
                severity = "Medium"
                query = "AzureActivity`n| take 10`n"
                tactics = @("InitialAccess")
                techniques = @()
                incidentConfiguration = @{
                    createIncident = $true
                    groupingConfiguration = @{ enabled = $null }
                }
            }
        },
        @{
            name = "vendor-rule-1"
            properties = @{
                displayName = "Vendor Rule 1"
                enabled = $true
                severity = "Low"
                query = "SecurityEvent | take 5"
            }
        }
    )
    Write-Host "Found $($allRules.Count) dummy rules in workspace" -ForegroundColor Green
} else {
    # Real API calls
    do {
        Write-Host "Fetching rules from: $nextLink" -ForegroundColor Yellow

        try {
            $response = Invoke-RestMethod -Uri $nextLink -Headers $headers -Method Get
            $allRules += $response.value
            $nextLink = $response.nextLink
        }
        catch {
            Write-Error "Failed to fetch rules: $_"
            exit 1
        }
    } while ($nextLink)

    Write-Host "Found $($allRules.Count) rules in workspace" -ForegroundColor Green
}

# Build desired state from Bicep templates
$desiredRules = @{}

# Change to repository root directory (important for GitHub Actions)
Set-Location $PSScriptRoot/..
Write-Host "Changed to repository root: $(Get-Location)" -ForegroundColor Green

# Determine the correct path for Bicep files based on organization
if ($Organization) {
    $bicepPath = "organizations/$Organization/env"
} else {
    $bicepPath = "env"
}

Write-Host "Looking for Bicep files in: $bicepPath" -ForegroundColor Yellow
Write-Host "Absolute path: $(Resolve-Path $bicepPath -ErrorAction SilentlyContinue)" -ForegroundColor Yellow

if (Test-Path $bicepPath) {
    Write-Host "Path exists: $bicepPath" -ForegroundColor Green
    $bicepFiles = Get-ChildItem -Path $bicepPath -Filter "deploy-*.bicep" -Recurse
    Write-Host "Found $($bicepFiles.Count) Bicep files" -ForegroundColor Yellow
    foreach ($file in $bicepFiles) {
        Write-Host "  - $($file.FullName)" -ForegroundColor Cyan
    }
} else {
    Write-Host "Path does not exist: $bicepPath" -ForegroundColor Red
    Write-Host "Available directories:" -ForegroundColor Yellow
    Get-ChildItem -Directory | ForEach-Object { Write-Host "  - $($_.Name)" -ForegroundColor Yellow }
    $bicepFiles = @()
}

Write-Host "Processing $($bicepFiles.Count) Bicep templates" -ForegroundColor Yellow
Write-Host "Found Bicep files: $($bicepFiles | ForEach-Object { $_.Name })" -ForegroundColor Yellow

foreach ($bicepFile in $bicepFiles) {
    try {
        Write-Host "Processing Bicep file: $($bicepFile.Name)" -ForegroundColor Yellow
        Write-Host "Full path: $($bicepFile.FullName)" -ForegroundColor Yellow

        # Build Bicep template to get compiled output
        Write-Host "Building Bicep template: $($bicepFile.FullName)" -ForegroundColor Yellow
        $buildOutput = az bicep build --file $bicepFile.FullName --stdout 2>&1

        Write-Host "Build exit code: $LASTEXITCODE" -ForegroundColor Yellow
        if ($buildOutput) {
            Write-Host "Build output length: $($buildOutput.Length)" -ForegroundColor Yellow
        }

        if ($LASTEXITCODE -ne 0) {
            Write-Warning "Failed to build Bicep template: $($bicepFile.Name)"
            Write-Warning "Build output: $buildOutput"
            Write-Host "Checking if Bicep CLI is available..." -ForegroundColor Yellow
            $bicepVersion = az bicep version 2>&1
            Write-Host "Bicep version check: $bicepVersion" -ForegroundColor Yellow
            continue
        }

        Write-Host "Successfully built Bicep template: $($bicepFile.Name)" -ForegroundColor Green

        $template = $buildOutput | ConvertFrom-Json


        Write-Host "Template has variables: $($template.variables -ne $null)" -ForegroundColor Yellow

        # Check for ARM template copy-generated variables (compiled Bicep)
        $rulesArray = $null
        if ($template.variables) {
            # Look for the compiled Bicep variable that contains the rules
            $fxvKey = $template.variables.PSObject.Properties | Where-Object { $_.Name -like '$fxv*' } | Select-Object -First 1
            if ($fxvKey) {
                $rulesArray = $fxvKey.Value
                Write-Host "Found rules in ARM copy variable: $($fxvKey.Name)" -ForegroundColor Green
            }
            # Also check for direct rules variable (fallback)
            elseif ($template.variables.rules) {
                $rulesArray = $template.variables.rules
                Write-Host "Found rules in variables.rules" -ForegroundColor Green
            }
        }

        if ($rulesArray) {
            Write-Host "Found $($rulesArray.Count) rules in variables" -ForegroundColor Green
            foreach ($rule in $rulesArray) {
                $ruleName = $rule.name
                Write-Host "Adding rule: $ruleName" -ForegroundColor Green
                
                # Look for KQL content in template variables - try different naming patterns
                $kqlContent = $null
                if ($rule.kql) {
                    $kqlContent = $rule.kql
                } elseif ($rule.kqlFile -and $template.variables) {
                    # Try to find KQL content in variables using the kqlFile name
                    $kqlVarName = "kql$($rule.name)"
                    if ($template.variables.$kqlVarName) {
                        $kqlContent = $template.variables.$kqlVarName
                    }
                }
                $desiredRules[$ruleName] = @{
                    displayName = $rule.displayName
                    enabled = $rule.enabled
                    severity = $rule.severity
                    query = $kqlContent
                    tactics = $rule.tactics
                    techniques = $rule.techniques
                    createIncident = $rule.createIncident
                    groupAlerts = $rule.grouping.enabled
                    source = "Bicep: $($bicepFile.Name)"
                }
            }
        }

        # Also check for direct alert rule resources (fallback for non-modular templates)
        if ($template.resources) {
            Write-Host "Template has $($template.resources.Count) resources" -ForegroundColor Yellow
            foreach ($resource in $template.resources.PSObject.Properties) {
                Write-Host "Resource type: $($resource.Value.type)" -ForegroundColor Yellow
                if ($resource.Value.type -eq "Microsoft.SecurityInsights/alertRules") {
                    $ruleName = $resource.Value.name
                    $properties = $resource.Value.properties

                    $desiredRules[$ruleName] = @{
                        displayName = $properties.displayName
                        enabled = $properties.enabled
                        severity = $properties.severity
                        query = $properties.query
                        tactics = $properties.tactics
                        techniques = $properties.techniques
                        createIncident = $properties.incidentConfiguration.createIncident
                        groupAlerts = $properties.incidentConfiguration.groupingConfiguration.enabled
                        source = "Bicep: $($bicepFile.Name)"
                    }
                }
            }
        }
    }
    catch {
        Write-Warning "Failed to process Bicep template $($bicepFile.Name): $_"
    }
}

Write-Host "Found $($desiredRules.Count) desired rules" -ForegroundColor Green
Write-Host "Desired rules: $($desiredRules.Keys -join ', ')" -ForegroundColor Yellow

# For local testing with dummy values, exit early if we found rules
if ($SubscriptionId -eq "dummy" -and $desiredRules.Count -gt 0) {
    Write-Host "✅ SUCCESS: Found desired rules in Bicep templates!" -ForegroundColor Green
    Write-Host "This means the Bicep parsing is working correctly." -ForegroundColor Green
    exit 0
}

# Compare desired vs actual state
$driftReport = @{
    timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss UTC"
    workspace = $Workspace
    summary = @{
        totalDesired = $desiredRules.Count
        totalActual = $allRules.Count
        driftFound = $false
        issues = @()
    }
    details = @()
}

foreach ($desiredRule in $desiredRules.GetEnumerator()) {
    $ruleName = $desiredRule.Key
    $desired = $desiredRule.Value
    
    # Find corresponding actual rule
    $actual = $allRules | Where-Object { $_.name -eq $ruleName } | Select-Object -First 1
    
    if (-not $actual) {
        $driftReport.summary.driftFound = $true
        $driftReport.details += @{
            ruleName = $ruleName
            issue = "Missing in workspace"
            desired = $desired
            actual = $null
        }
        $driftReport.summary.issues += "Rule '$ruleName' is missing in workspace"
        continue
    }
    
    $actualProps = $actual.properties
    $differences = @()
    
    # Compare key properties
    if ($desired.enabled -ne $actualProps.enabled) {
        $differences += "enabled: desired=$($desired.enabled), actual=$($actualProps.enabled)"
    }
    
    if ($desired.severity -ne $actualProps.severity) {
        $differences += "severity: desired=$($desired.severity), actual=$($actualProps.severity)"
    }
    
    if ($desired.query -ne $actualProps.query) {
        $differences += "query: different (length: desired=$($desired.query.Length), actual=$($actualProps.query.Length))"
    }
    
    if ($desired.createIncident -ne $actualProps.incidentConfiguration.createIncident) {
        $differences += "createIncident: desired=$($desired.createIncident), actual=$($actualProps.incidentConfiguration.createIncident)"
    }
    
    if ($desired.groupAlerts -ne $actualProps.incidentConfiguration.groupingConfiguration.enabled) {
        $differences += "groupAlerts: desired=$($desired.groupAlerts), actual=$($actualProps.incidentConfiguration.groupingConfiguration.enabled)"
    }
    
    if ($differences.Count -gt 0) {
        $driftReport.summary.driftFound = $true
        $driftReport.details += @{
            ruleName = $ruleName
            issue = "Configuration drift detected"
            differences = $differences
            desired = $desired
            actual = @{
                displayName = $actualProps.displayName
                enabled = $actualProps.enabled
                severity = $actualProps.severity
                query = $actualProps.query
                tactics = $actualProps.tactics
                techniques = $actualProps.techniques
                createIncident = $actualProps.incidentConfiguration.createIncident
                groupAlerts = $actualProps.incidentConfiguration.groupingConfiguration.enabled
            }
        }
        $driftReport.summary.issues += "Rule '$ruleName' has configuration drift: $($differences -join ', ')"
    }
}

# Check for extra rules in workspace (not in desired state)
foreach ($actual in $allRules) {
    if (-not $desiredRules.ContainsKey($actual.name)) {
        $driftReport.summary.driftFound = $true
        $driftReport.details += @{
            ruleName = $actual.name
            issue = "Extra rule in workspace (not in desired state)"
            desired = $null
            actual = @{
                displayName = $actual.properties.displayName
                enabled = $actual.properties.enabled
                severity = $actual.properties.severity
                source = "Workspace only"
            }
        }
        $driftReport.summary.issues += "Extra rule '$($actual.name)' found in workspace"
    }
}

# Generate report
$reportContent = @"
# Sentinel Drift Detection Report

**Generated:** $($driftReport.timestamp)  
**Workspace:** $($driftReport.workspace)

## Summary

- **Total Desired Rules:** $($driftReport.summary.totalDesired)
- **Total Actual Rules:** $($driftReport.summary.totalActual)
- **Drift Detected:** $($driftReport.summary.driftFound)

"@

if ($driftReport.summary.driftFound) {
    $reportContent += @"

## Issues Found

$($driftReport.summary.issues | ForEach-Object { "- $_" } | Out-String)

## Detailed Findings

"@

    foreach ($detail in $driftReport.details) {
        $reportContent += @"

### $($detail.ruleName)
**Issue:** $($detail.issue)

"@
        
        if ($detail.differences) {
            $reportContent += "**Differences:**`n"
            foreach ($diff in $detail.differences) {
                $reportContent += "- $diff`n"
            }
            $reportContent += "`n"
        }
        
        if ($detail.desired) {
            $reportContent += "**Desired State:**`n"
            $reportContent += "- Source: $($detail.desired.source)`n"
            $reportContent += "- Enabled: $($detail.desired.enabled)`n"
            $reportContent += "- Severity: $($detail.desired.severity)`n"
            $reportContent += "- Create Incident: $($detail.desired.createIncident)`n"
            $reportContent += "- Group Alerts: $($detail.desired.groupAlerts)`n`n"
        }
        
        if ($detail.actual) {
            $reportContent += "**Actual State:**`n"
            $reportContent += "- Display Name: $($detail.actual.displayName)`n"
            $reportContent += "- Enabled: $($detail.actual.enabled)`n"
            $reportContent += "- Severity: $($detail.actual.severity)`n"
            if ($detail.actual.createIncident -ne $null) {
                $reportContent += "- Create Incident: $($detail.actual.createIncident)`n"
                $reportContent += "- Group Alerts: $($detail.actual.groupAlerts)`n"
            }
            if ($detail.actual.source) {
                $reportContent += "- Source: $($detail.actual.source)`n"
            }
            $reportContent += "`n"
        }
    }
} else {
    $reportContent += @"

✅ **No drift detected!** All rules are in sync with the desired state.

"@
}

# Write report to file
$reportPath = "drift-report.md"
$reportContent | Out-File -FilePath $reportPath -Encoding UTF8

Write-Host "Drift detection completed" -ForegroundColor Green
Write-Host "Report saved to: $reportPath" -ForegroundColor Yellow

if ($driftReport.summary.driftFound) {
    Write-Host "❌ Drift detected! Found $($driftReport.summary.issues.Count) issues." -ForegroundColor Red
    exit 1
} else {
    Write-Host "✅ No drift detected" -ForegroundColor Green
    exit 0
}
