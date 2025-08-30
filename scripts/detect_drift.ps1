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
if (-not $SubscriptionId) {
    Write-Error "SUBSCRIPTION_ID environment variable is required"
    exit 1
}

if (-not $ResourceGroup) {
    Write-Error "RESOURCE_GROUP environment variable is required"
    exit 1
}

if (-not $Workspace) {
    Write-Error "WORKSPACE environment variable is required"
    exit 1
}

Write-Host "Detecting drift in workspace: $Workspace" -ForegroundColor Green

# Get access token
try {
    $token = (Get-AzAccessToken -ResourceUrl "https://management.azure.com").Token
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

# Build desired state from Bicep templates
$desiredRules = @{}

# Determine the correct path for Bicep files based on organization
if ($Organization) {
    $bicepPath = "organizations/$Organization/env"
} else {
    $bicepPath = "env"
}

Write-Host "Looking for Bicep files in: $bicepPath" -ForegroundColor Yellow
$bicepFiles = Get-ChildItem -Path $bicepPath -Filter "deploy-*.bicep" -Recurse

Write-Host "Processing $($bicepFiles.Count) Bicep templates" -ForegroundColor Yellow

foreach ($bicepFile in $bicepFiles) {
    try {
        # Build Bicep template to get compiled output
        $buildOutput = az bicep build --file $bicepFile.FullName --stdout 2>$null
        
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "Failed to build Bicep template: $($bicepFile.Name)"
            continue
        }
        
        $template = $buildOutput | ConvertFrom-Json
        
        # Extract rule properties from template
        foreach ($resource in $template.resources.PSObject.Properties) {
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
    catch {
        Write-Warning "Failed to process Bicep template $($bicepFile.Name): $_"
    }
}

Write-Host "Found $($desiredRules.Count) desired rules" -ForegroundColor Green

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
