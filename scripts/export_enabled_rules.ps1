#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Export enabled Microsoft Sentinel detection rules from Azure workspace.

.DESCRIPTION
    This script exports all enabled detection rules from a Microsoft Sentinel workspace
    and saves them as JSON files in the vendor/enabled directory.

.PARAMETER SubscriptionId
    Azure subscription ID (from environment variable SUBSCRIPTION_ID)

.PARAMETER ResourceGroup
    Resource group name (from environment variable RESOURCE_GROUP)

.PARAMETER Workspace
    Log Analytics workspace name (from environment variable WORKSPACE)

.PARAMETER ApiVersion
    API version to use (defaults to 2025-06-01)

.EXAMPLE
    .\export_enabled_rules.ps1
#>

param(
    [string]$SubscriptionId = $env:SUBSCRIPTION_ID,
    [string]$ResourceGroup = $env:RESOURCE_GROUP,
    [string]$Workspace = $env:WORKSPACE,
    [string]$ApiVersion = $env:API_VERSION
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

Write-Host "Exporting enabled rules from workspace: $Workspace" -ForegroundColor Green

# Get access token using Azure CLI
try {
    $tokenResponse = az account get-access-token --resource "https://management.azure.com" | ConvertFrom-Json
    if (-not $tokenResponse -or -not $tokenResponse.accessToken) {
        throw "Failed to get access token from Azure CLI"
    }
    $token = $tokenResponse.accessToken
    Write-Host "Successfully obtained access token" -ForegroundColor Green
}
catch {
    Write-Error "Failed to obtain access token: $_"
    Write-Host "Make sure you are logged in to Azure CLI with: az login" -ForegroundColor Yellow
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
        
        # Check for next page
        $nextLink = $response.nextLink
    }
    catch {
        Write-Error "Failed to fetch rules: $_"
        exit 1
    }
} while ($nextLink)

Write-Host "Found $($allRules.Count) total rules" -ForegroundColor Green

# Filter enabled rules
$enabledRules = $allRules | Where-Object { $_.properties.enabled -eq $true }

Write-Host "Found $($enabledRules.Count) enabled rules" -ForegroundColor Green

# Create output directory
$outputDir = "rules/vendor/enabled"
if (-not (Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
    Write-Host "Created output directory: $outputDir" -ForegroundColor Yellow
}

# Process each enabled rule
$exportedCount = 0
foreach ($rule in $enabledRules) {
    try {
        # Create safe filename
        $resourceName = $rule.name
        $displayName = $rule.properties.displayName
        
        # Sanitize display name for filename
        $safeDisplayName = $displayName -replace '[\\/:*?"<>|]', '_'
        $safeDisplayName = $safeDisplayName -replace '\s+', '_'
        $safeDisplayName = $safeDisplayName.Trim('_')
        
        $filename = "${resourceName}__${safeDisplayName}.json"
        $filepath = Join-Path $outputDir $filename
        
        # Remove noisy fields
        $cleanRule = $rule | Select-Object -Property * -ExcludeProperty etag
        
        # Remove timestamp fields if present
        $propertiesToRemove = @('lastModifiedUtc', 'createdTimeUtc', 'lastModifiedTimeUtc')
        foreach ($prop in $propertiesToRemove) {
            if ($cleanRule.properties.PSObject.Properties.Name -contains $prop) {
                $cleanRule.properties.PSObject.Properties.Remove($prop)
            }
        }
        
        # Convert to JSON with stable ordering
        $jsonContent = $cleanRule | ConvertTo-Json -Depth 10 -Compress:$false
        
        # Write to file
        $jsonContent | Out-File -FilePath $filepath -Encoding UTF8
        Write-Host "Exported: $filename" -ForegroundColor Green
        $exportedCount++
    }
    catch {
        Write-Warning "Failed to export rule $($rule.name): $_"
    }
}

Write-Host "Successfully exported $exportedCount enabled rules to $outputDir" -ForegroundColor Green
