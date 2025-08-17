#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Generate Sentinel rule configuration from KQL query

.DESCRIPTION
    Analyzes a KQL query file and automatically generates a rule configuration
    with appropriate entity mappings and custom details based on the projected columns.

.PARAMETER KqlFile
    Path to the KQL file to analyze

.PARAMETER RuleName
    Name for the rule (will be used to generate display name)

.PARAMETER Severity
    Severity level (Low, Medium, High, Critical)

.PARAMETER Environment
    Environment (dev or prod)

.PARAMETER Tactics
    Comma-separated list of MITRE ATT&CK tactics

.PARAMETER Techniques
    Comma-separated list of MITRE ATT&CK techniques

.PARAMETER CreateIncident
    Whether to create incidents (default: false for dev, true for prod)

.EXAMPLE
    .\generate-rule-config.ps1 -KqlFile "kql/my-detection.kql" -RuleName "suspicious-activity" -Severity "Medium" -Environment "dev" -Tactics "InitialAccess,Execution" -Techniques "T1078,T1059"

.NOTES
    This script analyzes the KQL query to automatically determine:
    - Entity mappings based on common column names
    - Custom details from projected columns
    - Appropriate grouping configuration
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$KqlFile,
    
    [Parameter(Mandatory = $true)]
    [string]$RuleName,
    
    [Parameter(Mandatory = $true)]
    [ValidateSet("Low", "Medium", "High", "Critical")]
    [string]$Severity,
    
    [Parameter(Mandatory = $true)]
    [ValidateSet("dev", "prod")]
    [string]$Environment,
    
    [Parameter(Mandatory = $true)]
    [string]$Tactics,
    
    [Parameter(Mandatory = $true)]
    [string]$Techniques,
    
    [bool]$CreateIncident = $false
)

# Set default CreateIncident based on environment if not specified
if ($CreateIncident -eq $false -and $Environment -eq "prod") {
    $CreateIncident = $true
}

# Read the KQL file
if (-not (Test-Path $KqlFile)) {
    Write-Error "KQL file not found: $KqlFile"
    exit 1
}

$kqlContent = Get-Content $KqlFile -Raw

# Extract projected columns from the KQL query
# Look for 'project' statement and extract column names
$projectMatch = [regex]::Match($kqlContent, 'project\s+(.+?)(?:\s*$|\s*\|)', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase -bor [System.Text.RegularExpressions.RegexOptions]::Singleline)

if (-not $projectMatch.Success) {
    Write-Warning "No 'project' statement found in KQL. Using basic configuration."
    $projectedColumns = @()
} else {
    $projectClause = $projectMatch.Groups[1].Value.Trim()
    # Split by comma and clean up column names
    $projectedColumns = $projectClause -split ',' | ForEach-Object { $_.Trim() }
}

Write-Host "📊 Analyzing KQL query..."
Write-Host "Projected columns: $($projectedColumns -join ', ')"

# Define entity mapping patterns
$entityMappings = @{
    # Account entity mappings
    "Account" = @{
        "SubjectUserName" = "accountFullName"
        "UserName" = "accountFullName"
        "UserPrincipalName" = "accountFullName"
        "AccountName" = "accountFullName"
        "User" = "accountFullName"
        "Identity" = "accountFullName"
    }
    
    # Host entity mappings
    "Host" = @{
        "Computer" = "hostName"
        "ComputerName" = "hostName"
        "HostName" = "hostName"
        "DeviceName" = "hostName"
        "MachineName" = "hostName"
        "SystemName" = "hostName"
    }
    
    # IP entity mappings
    "IP" = @{
        "IPAddress" = "ipAddress"
        "SourceIP" = "ipAddress"
        "DestinationIP" = "ipAddress"
        "ClientIP" = "ipAddress"
        "RemoteIP" = "ipAddress"
        "IP" = "ipAddress"
    }
}

# Analyze projected columns for entity mappings
$entities = @{}
$customDetails = @{}

foreach ($column in $projectedColumns) {
    $columnName = $column.Trim()
    
    # Check for entity mappings
    $entityFound = $false
    foreach ($entityType in $entityMappings.Keys) {
        foreach ($pattern in $entityMappings[$entityType].Keys) {
            if ($columnName -like "*$pattern*" -or $columnName -eq $pattern) {
                $entityKey = $entityMappings[$entityType][$pattern]
                $entities[$entityKey] = $columnName
                $entityFound = $true
                Write-Host "🔗 Found entity mapping: $columnName -> $entityKey"
                break
            }
        }
        if ($entityFound) { break }
    }
    
    # If not an entity, add as custom detail (exclude common system columns)
    if (-not $entityFound) {
        $excludeColumns = @("TimeGenerated", "Time", "Timestamp", "EventTime", "EventDateTime")
        if ($excludeColumns -notcontains $columnName) {
            $customDetails[$columnName] = $columnName
            Write-Host "📝 Added custom detail: $columnName"
        }
    }
}

# Generate display name
$envPrefix = $Environment.ToUpper()
$titleCase = (Get-Culture).TextInfo.ToTitleCase($RuleName.Replace('-', ' '))
$displayName = "[$envPrefix] [ORG] – $titleCase"

# Parse tactics and techniques
$tacticsArray = @($Tactics -split ',' | ForEach-Object { $_.Trim() })
$techniquesArray = @($Techniques -split ',' | ForEach-Object { $_.Trim() })

# Generate the rule configuration
$ruleConfig = @{
    name = $RuleName
    displayName = $displayName
    kqlFile = (Split-Path $KqlFile -Leaf)
    severity = $Severity
    enabled = $true
    frequency = "PT1H"
    period = "PT1H"
    tactics = $tacticsArray
    techniques = $techniquesArray
    createIncident = $CreateIncident
    grouping = @{
        enabled = $true
        matchingMethod = "AllEntities"
        lookbackDuration = "PT2H"
        reopenClosedIncident = $false
    }
    entities = $entities
    customDetails = $customDetails
}

# Convert to JSON with proper formatting
$jsonOutput = $ruleConfig | ConvertTo-Json -Depth 10

Write-Host "`n🎉 Generated rule configuration:"
Write-Host "=================================="
Write-Host $jsonOutput

# Save to file
$outputFile = "env/rules/generated-$RuleName.json"
$jsonOutput | Out-File -FilePath $outputFile -Encoding UTF8

Write-Host "`n💾 Configuration saved to: $outputFile"
Write-Host "`n📋 Next steps:"
Write-Host "1. Review the generated configuration"
Write-Host "2. Copy the rule object to env/rules/$Environment-rules.json"
Write-Host "3. Adjust severity, tactics, or other settings as needed"
Write-Host "4. Commit and deploy!"

return $ruleConfig
