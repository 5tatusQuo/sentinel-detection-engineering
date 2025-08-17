#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Quick script to create a new Sentinel detection rule

.DESCRIPTION
    Interactive script that helps you create a new detection rule by:
    1. Creating the KQL file
    2. Generating the rule configuration
    3. Adding it to the appropriate environment files

.EXAMPLE
    .\new-rule.ps1
#>

Write-Host "🎯 Sentinel Rule Creator" -ForegroundColor Green
Write-Host "========================`n"

# Get rule details
$ruleName = Read-Host "Enter rule name (e.g., suspicious-login-attempts)"
$displayName = Read-Host "Enter display name (e.g., Suspicious Login Attempts)"
$severity = Read-Host "Enter severity (Low/Medium/High/Critical)" | ForEach-Object { $_.ToLower() }
$tactics = Read-Host "Enter ATT&CK tactics (comma-separated, e.g., InitialAccess,Execution)"
$techniques = Read-Host "Enter ATT&CK techniques (comma-separated, e.g., T1078,T1059)"

# Validate severity
$validSeverities = @("low", "medium", "high", "critical")
if ($severity -notin $validSeverities) {
    Write-Error "Invalid severity. Must be one of: $($validSeverities -join ', ')"
    exit 1
}

# Create KQL file
$kqlFile = "kql/$ruleName.kql"
Write-Host "`n📝 Creating KQL file: $kqlFile"

# Get KQL query
Write-Host "`nEnter your KQL query (press Enter twice when done):"
$kqlLines = @()
do {
    $line = Read-Host "KQL"
    if ($line -ne "") {
        $kqlLines += $line
    }
} while ($line -ne "")

if ($kqlLines.Count -eq 0) {
    Write-Error "No KQL query provided"
    exit 1
}

# Write KQL file
$kqlContent = $kqlLines -join "`n"
$kqlContent | Out-File -FilePath $kqlFile -Encoding UTF8
Write-Host "✅ KQL file created: $kqlFile"

# Generate configurations for both environments
Write-Host "`n🔧 Generating rule configurations..."

# Dev environment
Write-Host "Generating DEV configuration..."
$devConfig = & .\scripts\generate-rule-config.ps1 -KqlFile $kqlFile -RuleName $ruleName -Severity $severity -Environment "dev" -Tactics $tactics -Techniques $techniques -CreateIncident $false

# Prod environment (higher severity)
$prodSeverity = switch ($severity) {
    "low" { "Medium" }
    "medium" { "High" }
    "high" { "High" }
    "critical" { "Critical" }
}

Write-Host "Generating PROD configuration..."
$prodConfig = & .\scripts\generate-rule-config.ps1 -KqlFile $kqlFile -RuleName $ruleName -Severity $prodSeverity -Environment "prod" -Tactics $tactics -Techniques $techniques -CreateIncident $true

Write-Host "`n🎉 Rule creation complete!" -ForegroundColor Green
Write-Host "`n📋 Next steps:"
Write-Host "1. Review the generated configurations in env/rules/generated-*.json"
Write-Host "2. Copy the rule objects to env/rules/dev-rules.json and env/rules/prod-rules.json"
Write-Host "3. Test your KQL query in Azure Sentinel Logs"
Write-Host "4. Commit your changes and deploy!"

Write-Host "`n📁 Files created:"
Write-Host "  - $kqlFile"
Write-Host "  - env/rules/generated-$ruleName-dev.json"
Write-Host "  - env/rules/generated-$ruleName-prod.json"
