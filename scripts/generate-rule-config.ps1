#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Generate Sentinel rule configuration from KQL query

.DESCRIPTION
    Analyzes a KQL query file and automatically generates a rule configuration
    with appropriate entity mappings and custom details based on the projected columns.
    Automatically adds the generated code to the appropriate Bicep deployment files.

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
    Then automatically adds the code to the appropriate Bicep files.
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

# Generate Bicep code
$kqlVarName = "kql$($RuleName.Replace('-', '').Replace('_', ''))"
$kqlFileName = Split-Path $KqlFile -Leaf

# Build entities Bicep code
$entitiesBicep = ""
if ($entities.Count -gt 0) {
    $entityLines = @()
    foreach ($entity in $entities.GetEnumerator()) {
        $entityLines += "      $($entity.Key): '$($entity.Value)'"
    }
    $entitiesBicep = "`n    entities: {`n$($entityLines -join "`n")`n    }"
}

# Build custom details Bicep code
$customDetailsBicep = ""
if ($customDetails.Count -gt 0) {
    $detailLines = @()
    foreach ($detail in $customDetails.GetEnumerator()) {
        $detailLines += "      $($detail.Key): '$($detail.Value)'"
    }
    $customDetailsBicep = "`n    customDetails: {`n$($detailLines -join "`n")`n    }"
}

# Build tactics array
$tacticsQuoted = $tacticsArray | ForEach-Object { "'$_'" }
$tacticsBicep = "[ " + ($tacticsQuoted -join ", ") + " ]"

# Build techniques array  
$techniquesQuoted = $techniquesArray | ForEach-Object { "'$_'" }
$techniquesBicep = "[ " + ($techniquesQuoted -join ", ") + " ]"

# Generate the complete Bicep rule object
$bicepRule = @"
  {
    name: '$RuleName'
    displayName: '$displayName'
    kql: $kqlVarName
    severity: '$Severity'
    enabled: true
    frequency: 'PT1H'
    period: 'PT1H'
    tactics: $tacticsBicep
    techniques: $techniquesBicep
    createIncident: $($CreateIncident.ToString().ToLower())
    grouping: {
      enabled: true
      matchingMethod: 'AllEntities'
    }$entitiesBicep$customDetailsBicep
  }
"@

# Generate the KQL loading line
$kqlLoadingLine = "var $kqlVarName = loadTextContent('../kql/$kqlFileName')"

Write-Host "`n🎉 Generated Bicep configuration:"
Write-Host "=================================="
Write-Host "`n📝 KQL loading line:"
Write-Host "----------------------------------------"
Write-Host $kqlLoadingLine
Write-Host "`n📋 Rule object:"
Write-Host "----------------------------------------"
Write-Host $bicepRule

# Now automatically add to the Bicep file
$bicepFile = "env/deploy-$Environment.bicep"

if (-not (Test-Path $bicepFile)) {
    Write-Error "Bicep file not found: $bicepFile"
    exit 1
}

Write-Host "`n🔧 Adding to $bicepFile..."

# Read the current Bicep file
$bicepLines = Get-Content $bicepFile

# Find the line after the last KQL loading line
$kqlLoadingIndex = -1
for ($i = 0; $i -lt $bicepLines.Count; $i++) {
    if ($bicepLines[$i] -match '^var kql\w+ = loadTextContent') {
        $kqlLoadingIndex = $i
    }
}

# Insert KQL loading line after the last KQL loading line
if ($kqlLoadingIndex -ge 0) {
    $bicepLines = $bicepLines[0..$kqlLoadingIndex] + $kqlLoadingLine + $bicepLines[($kqlLoadingIndex + 1)..($bicepLines.Count - 1)]
} else {
    # If no KQL loading lines found, insert after the workspace parameter
    $paramIndex = -1
    for ($i = 0; $i -lt $bicepLines.Count; $i++) {
        if ($bicepLines[$i] -match '^param workspaceName') {
            $paramIndex = $i
            break
        }
    }
    if ($paramIndex -ge 0) {
        $bicepLines = $bicepLines[0..$paramIndex] + "" + "// Load KQL files" + $kqlLoadingLine + $bicepLines[($paramIndex + 1)..($bicepLines.Count - 1)]
    }
}

# Find the rules array and add the new rule
$rulesArrayStart = -1
$rulesArrayEnd = -1
$bracketCount = 0
$inRulesArray = $false

for ($i = 0; $i -lt $bicepLines.Count; $i++) {
    $line = $bicepLines[$i]
    
    if ($line -match '^var rules = \[') {
        $rulesArrayStart = $i
        $inRulesArray = $true
        $bracketCount = 1
    } elseif ($inRulesArray) {
        if ($line -match '\[') {
            $bracketCount++
        }
        if ($line -match '\]') {
            $bracketCount--
            if ($bracketCount -eq 0) {
                $rulesArrayEnd = $i
                break
            }
        }
    }
}

if ($rulesArrayStart -ge 0 -and $rulesArrayEnd -ge 0) {
    # Insert the new rule before the closing bracket
    $bicepLines = $bicepLines[0..($rulesArrayEnd - 1)] + $bicepRule + $bicepLines[$rulesArrayEnd..($bicepLines.Count - 1)]
    Write-Host "✅ Successfully added rule to $bicepFile"
} else {
    Write-Error "Could not find rules array in $bicepFile"
    exit 1
}

# Write the updated content back to the file
$bicepLines | Out-File -FilePath $bicepFile -Encoding UTF8

# Save a backup of the generated configuration
$outputFile = "env/rules/generated-$RuleName-$Environment.bicep"
$output = @"
// Generated rule configuration for $RuleName ($Environment)
// KQL loading line:
$kqlLoadingLine

// Rule object:
$bicepRule
"@

$output | Out-File -FilePath $outputFile -Encoding UTF8

Write-Host "`n💾 Backup saved to: $outputFile"
Write-Host "`n📋 Next steps:"
Write-Host "1. Review the changes in $bicepFile"
Write-Host "2. Test your Bicep file with: az bicep build --file $bicepFile"
Write-Host "3. Commit and deploy!"

return @{
    KqlLoadingLine = $kqlLoadingLine
    BicepRule = $bicepRule
    Entities = $entities
    CustomDetails = $customDetails
    BicepFile = $bicepFile
}
