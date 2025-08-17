#!/usr/bin/env pwsh

<#
.SYNOPSIS
    Syncs changes made in Azure Sentinel portal back to repository files.

.DESCRIPTION
    This script exports current Sentinel alert rules from the dev environment,
    compares them with repository files, and automatically updates KQL and Bicep
    files to match the portal configuration.

.PARAMETER ResourceGroup
    The resource group containing the Sentinel workspace.

.PARAMETER WorkspaceName
    The name of the Sentinel workspace.

.PARAMETER RuleName
    Optional. Specific rule name to sync. If not provided, syncs all rules.

.PARAMETER DryRun
    Optional. Shows what would be changed without making changes.

.EXAMPLE
    .\sync-sentinel-changes.ps1 -ResourceGroup "SENTINEL_RG_DEV" -WorkspaceName "SENTINEL_WS_DEV"

.EXAMPLE
    .\sync-sentinel-changes.ps1 -ResourceGroup "SENTINEL_RG_DEV" -WorkspaceName "SENTINEL_WS_DEV" -RuleName "test5" -DryRun
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroup,
    
    [Parameter(Mandatory = $true)]
    [string]$WorkspaceName,
    
    [Parameter(Mandatory = $false)]
    [string]$RuleName,
    
    [Parameter(Mandatory = $false)]
    [switch]$DryRun
)

# Set error action preference
$ErrorActionPreference = "Stop"

Write-Host "🔄 Starting Sentinel to Repository Sync..." -ForegroundColor Cyan
Write-Host "Resource Group: $ResourceGroup" -ForegroundColor Yellow
Write-Host "Workspace: $WorkspaceName" -ForegroundColor Yellow
if ($RuleName) {
    Write-Host "Target Rule: $RuleName" -ForegroundColor Yellow
}
if ($DryRun) {
    Write-Host "DRY RUN MODE - No changes will be made" -ForegroundColor Red
}
Write-Host ""

# Function to clean rule name (remove environment prefix)
function Get-CleanRuleName {
    param([string]$DisplayName)
    
    # Remove environment prefixes like [DEV] [ORG] –
    $cleanName = $DisplayName -replace '^\[(DEV|PROD)\]\s*\[[^\]]+\]\s*–\s*', ''
    return $cleanName
}

# Function to extract rule name from display name
function Get-RuleNameFromDisplay {
    param([string]$DisplayName)
    
    $cleanName = Get-CleanRuleName -DisplayName $DisplayName
    # Convert to lowercase and replace spaces with hyphens
    $ruleName = $cleanName.ToLower() -replace '\s+', '-'
    return $ruleName
}

# Function to update KQL file
function Update-KqlFile {
    param(
        [string]$RuleName,
        [string]$Query
    )
    
    $kqlPath = "kql/$RuleName.kql"
    
    if ($DryRun) {
        Write-Host "📝 Would update KQL file: $kqlPath" -ForegroundColor Yellow
        Write-Host "   Query: $Query" -ForegroundColor Gray
        return
    }
    
    try {
        # Ensure kql directory exists
        if (!(Test-Path "kql")) {
            New-Item -ItemType Directory -Path "kql" -Force | Out-Null
        }
        
        # Write the query to file
        $Query | Out-File -FilePath $kqlPath -Encoding UTF8
        Write-Host "✅ Updated KQL file: $kqlPath" -ForegroundColor Green
    }
    catch {
        Write-Host "❌ Failed to update KQL file: $kqlPath" -ForegroundColor Red
        Write-Host "   Error: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Function to update Bicep configuration
function Update-BicepConfig {
    param(
        [string]$RuleName,
        [object]$RuleConfig
    )
    
    $devBicepPath = "env/deploy-dev.bicep"
    $prodBicepPath = "env/deploy-prod.bicep"
    
    if ($DryRun) {
        Write-Host "📝 Would update Bicep files:" -ForegroundColor Yellow
        Write-Host "   Dev: $devBicepPath" -ForegroundColor Gray
        Write-Host "   Prod: $prodBicepPath" -ForegroundColor Gray
        return
    }
    
    try {
        # Read existing Bicep files
        $devContent = Get-Content -Path $devBicepPath -Raw
        $prodContent = Get-Content -Path $prodBicepPath -Raw
        
        # Create rule object for dev
        $devRuleObject = @"
  {
    name: '$RuleName'
    displayName: '[DEV] [ORG] – $($RuleConfig.displayName)'
    kql: kql$RuleName
    severity: '$($RuleConfig.severity)'
    enabled: $($RuleConfig.enabled.ToString().ToLower())
    frequency: '$($RuleConfig.queryFrequency)'
    period: '$($RuleConfig.queryPeriod)'
    tactics: [ $($RuleConfig.tactics -join ', ') ]
    techniques: [ $($RuleConfig.techniques -join ', ') ]
    createIncident: $($RuleConfig.createIncident.ToString().ToLower())
    grouping: {
      enabled: $($RuleConfig.groupingEnabled.ToString().ToLower())
      matchingMethod: '$($RuleConfig.groupingMethod)'
    }
    entities: {
      ipAddress: '$($RuleConfig.entities.ipAddress)'
      accountFullName: '$($RuleConfig.entities.accountFullName)'
      hostName: '$($RuleConfig.entities.hostName)'
    }
    customDetails: {
      $($RuleConfig.customDetails -join "`n      ")
    }
  }
"@

        # Create rule object for prod (escalate severity)
        $prodSeverity = switch ($RuleConfig.severity) {
            "Low" { "Medium" }
            "Medium" { "High" }
            "High" { "Critical" }
            "Critical" { "Critical" }
            default { "Medium" }
        }
        
        $prodRuleObject = @"
  {
    name: '$RuleName'
    displayName: '[PROD] [ORG] – $($RuleConfig.displayName)'
    kql: kql$RuleName
    severity: '$prodSeverity'
    enabled: $($RuleConfig.enabled.ToString().ToLower())
    frequency: '$($RuleConfig.queryFrequency)'
    period: '$($RuleConfig.queryPeriod)'
    tactics: [ $($RuleConfig.tactics -join ', ') ]
    techniques: [ $($RuleConfig.techniques -join ', ') ]
    createIncident: true
    grouping: {
      enabled: $($RuleConfig.groupingEnabled.ToString().ToLower())
      matchingMethod: '$($RuleConfig.groupingMethod)'
    }
    entities: {
      ipAddress: '$($RuleConfig.entities.ipAddress)'
      accountFullName: '$($RuleConfig.entities.accountFullName)'
      hostName: '$($RuleConfig.entities.hostName)'
    }
    customDetails: {
      $($RuleConfig.customDetails -join "`n      ")
    }
  }
"@

        # Update dev Bicep file
        $devContent = $devContent -replace "(?s)  \{\s*name: '$RuleName'.*?\n  \}", $devRuleObject
        $devContent | Out-File -FilePath $devBicepPath -Encoding UTF8
        
        # Update prod Bicep file
        $prodContent = $prodContent -replace "(?s)  \{\s*name: '$RuleName'.*?\n  \}", $prodRuleObject
        $prodContent | Out-File -FilePath $prodBicepPath -Encoding UTF8
        
        Write-Host "✅ Updated Bicep files for rule: $RuleName" -ForegroundColor Green
    }
    catch {
        Write-Host "❌ Failed to update Bicep files for rule: $RuleName" -ForegroundColor Red
        Write-Host "   Error: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Main execution
try {
    Write-Host "🔍 Fetching rules from Sentinel..." -ForegroundColor Cyan
    
    # Get rules from Sentinel
    $rules = az sentinel alert-rule list `
        --resource-group $ResourceGroup `
        --workspace-name $WorkspaceName `
        --query '[].{
            name: name,
            displayName: displayName,
            query: query,
            severity: severity,
            enabled: enabled,
            queryFrequency: queryFrequency,
            queryPeriod: queryPeriod,
            tactics: tactics,
            techniques: techniques,
            createIncident: createIncident,
            groupingEnabled: groupingEnabled,
            groupingMethod: groupingMethod,
            entityMappings: entityMappings,
            customDetails: customDetails
        }' `
        --output json | ConvertFrom-Json
    
    if (!$rules) {
        Write-Host "❌ No rules found in Sentinel workspace" -ForegroundColor Red
        exit 1
    }
    
    Write-Host "📊 Found $($rules.Count) rules in Sentinel" -ForegroundColor Green
    
    # Filter by specific rule if provided
    if ($RuleName) {
        $rules = $rules | Where-Object { $_.name -eq $RuleName }
        if (!$rules) {
            Write-Host "❌ Rule '$RuleName' not found in Sentinel" -ForegroundColor Red
            exit 1
        }
        Write-Host "🎯 Syncing specific rule: $RuleName" -ForegroundColor Yellow
    }
    
    $updatedCount = 0
    
    foreach ($rule in $rules) {
        $cleanRuleName = Get-RuleNameFromDisplay -DisplayName $rule.displayName
        
        Write-Host "`n🔄 Processing rule: $($rule.displayName)" -ForegroundColor Cyan
        Write-Host "   Clean name: $cleanRuleName" -ForegroundColor Gray
        
        # Extract entity mappings
        $entities = @{
            ipAddress = ""
            accountFullName = ""
            hostName = ""
        }
        
        if ($rule.entityMappings) {
            foreach ($mapping in $rule.entityMappings) {
                switch ($mapping.entityType) {
                    "IP" { $entities.ipAddress = $mapping.fieldMappings[0].columnName }
                    "Account" { $entities.accountFullName = $mapping.fieldMappings[0].columnName }
                    "Host" { $entities.hostName = $mapping.fieldMappings[0].columnName }
                }
            }
        }
        
        # Extract custom details
        $customDetails = @()
        if ($rule.customDetails) {
            foreach ($detail in $rule.customDetails.PSObject.Properties) {
                $customDetails += "$($detail.Name): '$($detail.Value)'"
            }
        }
        
        # Create rule config object
        $ruleConfig = @{
            displayName = Get-CleanRuleName -DisplayName $rule.displayName
            severity = $rule.severity
            enabled = $rule.enabled
            queryFrequency = $rule.queryFrequency
            queryPeriod = $rule.queryPeriod
            tactics = $rule.tactics
            techniques = $rule.techniques
            createIncident = $rule.createIncident
            groupingEnabled = $rule.groupingEnabled
            groupingMethod = $rule.groupingMethod
            entities = $entities
            customDetails = $customDetails
        }
        
        # Update KQL file
        Update-KqlFile -RuleName $cleanRuleName -Query $rule.query
        
        # Update Bicep configuration
        Update-BicepConfig -RuleName $cleanRuleName -RuleConfig $ruleConfig
        
        $updatedCount++
    }
    
    Write-Host "`n🎉 Sync completed!" -ForegroundColor Green
    Write-Host "   Updated $updatedCount rule(s)" -ForegroundColor Yellow
    
    if ($DryRun) {
        Write-Host "`n💡 To apply these changes, run without -DryRun flag" -ForegroundColor Cyan
    } else {
        Write-Host "`n📝 Next steps:" -ForegroundColor Cyan
        Write-Host "   1. Review the changes in git" -ForegroundColor White
        Write-Host "   2. Commit and push to feature branch" -ForegroundColor White
        Write-Host "   3. Automatic deployment will verify the sync" -ForegroundColor White
    }
    
}
catch {
    Write-Host "❌ Error during sync: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
