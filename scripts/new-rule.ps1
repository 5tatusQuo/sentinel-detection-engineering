#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Quick script to create a new Sentinel detection rule

.DESCRIPTION
    Interactive script that helps you create a new detection rule by:
    1. Creating the KQL file
    2. Generating the Bicep configuration
    3. Providing copy-paste instructions for adding to deployment files

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
Write-Host "`n🔧 Generating Bicep configurations..."

# Dev environment
Write-Host "`n📝 Generating DEV configuration..."
$devConfig = & .\scripts\generate-rule-config.ps1 -KqlFile $kqlFile -RuleName $ruleName -Severity $severity -Environment "dev" -Tactics $tactics -Techniques $techniques -CreateIncident $false

# Prod environment (higher severity)
$prodSeverity = switch ($severity) {
    "low" { "Medium" }
    "medium" { "High" }
    "high" { "High" }
    "critical" { "Critical" }
}

Write-Host "`n📝 Generating PROD configuration..."
$prodConfig = & .\scripts\generate-rule-config.ps1 -KqlFile $kqlFile -RuleName $ruleName -Severity $prodSeverity -Environment "prod" -Tactics $tactics -Techniques $techniques -CreateIncident $true

Write-Host "`n🎉 Rule creation complete!" -ForegroundColor Green
Write-Host "`n📋 What was done:"
Write-Host "1. ✅ Created KQL file: $kqlFile"
Write-Host "2. ✅ Generated DEV configuration: env/rules/generated-$ruleName-dev.bicep"
Write-Host "3. ✅ Generated PROD configuration: env/rules/generated-$ruleName-prod.bicep"

Write-Host "`n📋 Next steps:"
Write-Host "1. Open the generated .bicep files to see what to copy"
Write-Host "2. Copy the KQL loading lines to env/deploy-dev.bicep and env/deploy-prod.bicep"
Write-Host "3. Copy the rule objects to the rules arrays in both Bicep files"
Write-Host "4. Test your Bicep files:"
Write-Host "   - az bicep build --file env/deploy-dev.bicep"
Write-Host "   - az bicep build --file env/deploy-prod.bicep"
Write-Host "5. Test your KQL query in Azure Sentinel Logs"
Write-Host "6. Commit your changes and deploy!"

Write-Host "`n📁 Files created:"
Write-Host "  - $kqlFile (new)"
Write-Host "  - env/rules/generated-$ruleName-dev.bicep (copy instructions)"
Write-Host "  - env/rules/generated-$ruleName-prod.bicep (copy instructions)"

Write-Host "`n💡 Pro tip: The script automatically analyzed your KQL and added appropriate entity mappings and custom details!"
Write-Host "💡 Pro tip: Open the generated .bicep files to see exactly what to copy!"
