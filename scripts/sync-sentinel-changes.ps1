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
    [string]$Environment = "dev",
    
    [Parameter(Mandatory = $false)]
    [bool]$IncludeVendorRules = $false,
    
    [Parameter(Mandatory = $false)]
    [bool]$CreateBranch = $true,
    
    [Parameter(Mandatory = $false)]
    [bool]$ForceSync = $false,
    
    [Parameter(Mandatory = $false)]
    [switch]$DryRun
)

# Set error action preference
$ErrorActionPreference = "Stop"

Write-Host "🔄 Starting Sentinel to Repository Sync..." -ForegroundColor Cyan
Write-Host "Resource Group: $ResourceGroup" -ForegroundColor Yellow
Write-Host "Workspace: $WorkspaceName" -ForegroundColor Yellow
Write-Host "Environment: $Environment" -ForegroundColor Yellow
Write-Host "Include Vendor Rules: $IncludeVendorRules" -ForegroundColor Yellow
Write-Host "Create Branch: $CreateBranch" -ForegroundColor Yellow
Write-Host "Force Sync: $ForceSync" -ForegroundColor Yellow
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
        
        # Create rule object based on environment
        $envPrefix = if ($Environment -eq "prod") { "[PROD]" } else { "[DEV]" }
        $envSeverity = if ($Environment -eq "prod") {
            # Escalate severity for prod
            switch ($RuleConfig.severity) {
                "Low" { "Medium" }
                "Medium" { "High" }
                "High" { "Critical" }
                "Critical" { "Critical" }
                default { "Medium" }
            }
        } else {
            $RuleConfig.severity
        }
        $envCreateIncident = if ($Environment -eq "prod") { "true" } else { $($RuleConfig.createIncident.ToString().ToLower()) }
        
        $ruleObject = @"
  {
    name: '$RuleName'
    displayName: '$envPrefix [ORG] – $($RuleConfig.displayName)'
    kql: kql$RuleName
    severity: '$envSeverity'
    enabled: $($RuleConfig.enabled.ToString().ToLower())
    frequency: '$($RuleConfig.queryFrequency)'
    period: '$($RuleConfig.queryPeriod)'
    tactics: [ $($RuleConfig.tactics -join ', ') ]
    techniques: [ $($RuleConfig.techniques -join ', ') ]
    createIncident: $envCreateIncident
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

        # Update appropriate Bicep file based on environment
        if ($Environment -eq "prod") {
            $prodContent = $prodContent -replace "(?s)  \{\s*name: '$RuleName'.*?\n  \}", $ruleObject
            $prodContent | Out-File -FilePath $prodBicepPath -Encoding UTF8
            Write-Host "✅ Updated PROD Bicep file for rule: $RuleName" -ForegroundColor Green
        } else {
            $devContent = $devContent -replace "(?s)  \{\s*name: '$RuleName'.*?\n  \}", $ruleObject
            $devContent | Out-File -FilePath $devBicepPath -Encoding UTF8
            Write-Host "✅ Updated DEV Bicep file for rule: $RuleName" -ForegroundColor Green
        }
        
        # Removed duplicate line
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
    
    # Filter vendor rules if not included
    if (!$IncludeVendorRules) {
        $originalCount = $rules.Count
        $rules = $rules | Where-Object { 
            # Exclude vendor rules (typically have specific naming patterns)
            $_.displayName -notmatch '^\[(Microsoft|Azure|Sentinel|BuiltIn|Fusion)' -and
            $_.displayName -notmatch 'Microsoft' -and
            $_.displayName -notmatch 'Azure' -and
            $_.displayName -notmatch 'Sentinel'
        }
        $filteredCount = $rules.Count
        Write-Host "🔍 Filtered out vendor rules: $originalCount -> $filteredCount custom rules" -ForegroundColor Yellow
    } else {
        Write-Host "🔍 Including all rules (custom + vendor)" -ForegroundColor Yellow
    }
    
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
