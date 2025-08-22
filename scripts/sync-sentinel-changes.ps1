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
    [string]$Organization = "org1",
    
    [Parameter(Mandatory = $false)]
    [switch]$CreateBranch,

    [Parameter(Mandatory = $false)]
    [switch]$DryRun,

    [Parameter(Mandatory = $false)]
    [switch]$ForceSync
)

# Helper functions
function Get-OrganizationPaths {
    param([string]$OrganizationName, [string]$Environment)
    
    $orgRoot = "organizations/$OrganizationName"
    
    return @{
        EnvDirectory = "$orgRoot/env"
        KqlDirectory = "$orgRoot/kql/$Environment"
        BicepPath = "$orgRoot/env/deploy-$Environment.bicep"
    }
}

function Get-CleanRuleName {
    param([string]$DisplayName)
    return $DisplayName -replace '[^a-zA-Z0-9\s]', '' -replace '\s+', ' '
}

function Get-RuleNameFromDisplay {
    param([string]$DisplayName)
    $cleanName = Get-CleanRuleName -DisplayName $DisplayName
    return $cleanName.ToLower() -replace '[^a-z0-9\s]', '' -replace '\s+', '-'
}

function Convert-TimeSpanToISO8601 {
    param([string]$TimeSpanValue)
    
    if ([string]::IsNullOrEmpty($TimeSpanValue)) {
        return $TimeSpanValue
    }
    
    # If it's already in ISO 8601 format (starts with PT or P), return as-is
    if ($TimeSpanValue -match '^P') {
        return $TimeSpanValue
    }
    
    try {
        # Try to parse as TimeSpan (e.g., "0:05:00" or "00:05:00")
        $timespan = [TimeSpan]::Parse($TimeSpanValue)
        
        # Convert to ISO 8601 format
        if ($timespan.TotalDays -ge 1) {
            return "P$($timespan.Days)DT$($timespan.Hours)H$($timespan.Minutes)M$($timespan.Seconds)S"
        } elseif ($timespan.TotalHours -ge 1) {
            return "PT$($timespan.Hours)H$($timespan.Minutes)M"
        } else {
            return "PT$($timespan.Minutes)M"
        }
    } catch {
        Write-Host "Warning: Could not convert '$TimeSpanValue' to ISO 8601 format: $($_.Exception.Message)" -ForegroundColor Yellow
        return $TimeSpanValue
    }
}

function Find-DeletedRules {
    param([array]$PortalRules, [string]$Organization)
    
    Write-Host "`n🔍 Looking for deleted rules..." -ForegroundColor Cyan
    
    # Check both dev and prod environments for deleted rules
    foreach ($env in @("dev", "prod")) {
        Write-Host "   📁 Checking $env environment..." -ForegroundColor Gray
        
        $paths = Get-OrganizationPaths -OrganizationName $Organization -Environment $env
        if (-not (Test-Path "$($paths.KqlDirectory)/*.kql")) {
            Write-Host "   ✅ No KQL files found in ${env}" -ForegroundColor Green
            continue
        }
        
        $kqlFiles = Get-ChildItem "$($paths.KqlDirectory)/*.kql"
        $deletedRules = @()
        
        foreach ($kqlFile in $kqlFiles) {
            $ruleBaseName = $kqlFile.BaseName
            
            # Check if this KQL file corresponds to a rule that still exists in the portal
            $found = $false
            foreach ($portalRule in $PortalRules) {
                $generatedName = Get-RuleNameFromDisplay -DisplayName $portalRule.displayName
                if ($generatedName -eq $ruleBaseName) {
                    $found = $true
                    break
                }
            }
            
            if (-not $found) {
                $deletedRules += @{
                    RuleName = $ruleBaseName
                    KqlFile = $kqlFile.FullName
                    Environment = $env
                }
            }
        }
        
        if ($deletedRules.Count -gt 0) {
            Write-Host "   🗑️  Found $($deletedRules.Count) deleted rules in ${env}:" -ForegroundColor Yellow
            foreach ($rule in $deletedRules) {
                Write-Host "     - $($rule.RuleName)" -ForegroundColor Red
            }
            
            if (-not $DryRun) {
                $response = Read-Host "   Do you want to remove these rules from ${env}? (y/N)"
                if ($response -eq 'y' -or $response -eq 'Y') {
                    foreach ($rule in $deletedRules) {
                        Remove-RuleFromBicep -RuleName $rule.RuleName -Organization $Organization -Environment $rule.Environment
                        Remove-UnusedKqlFile -KqlFilePath $rule.KqlFile
                    }
                }
            } else {
                Write-Host "   📝 DryRun: Would prompt to remove deleted rules from ${env}" -ForegroundColor Yellow
            }
        } else {
            Write-Host "   ✅ No deleted rules found in ${env}" -ForegroundColor Green
        }
    }
}

function Remove-RuleFromBicep {
    param([string]$RuleName, [string]$Organization, [string]$Environment)
    
    Write-Host "🗑️  Removing rule '$RuleName' from Bicep files..." -ForegroundColor Yellow
    
    # For now, just report what would be removed
    # Full implementation would use the inline script approach
    Write-Host "   ⚠️  Rule removal from Bicep not yet implemented - manual removal required" -ForegroundColor Yellow
}

function Remove-UnusedKqlFile {
    param([string]$KqlFilePath)
    
    if (Test-Path $KqlFilePath) {
        Write-Host "🗑️  Removing unused KQL file: $KqlFilePath" -ForegroundColor Yellow
        
        if (-not $DryRun) {
            Remove-Item $KqlFilePath -Force
            Write-Host "   ✅ Removed KQL file" -ForegroundColor Green
        } else {
            Write-Host "   📝 DryRun: Would remove KQL file" -ForegroundColor Yellow
        }
    }
}

function Update-KqlFile {
    param([string]$KqlPath, [string]$Query)
    
    try {
        if (Test-Path $KqlPath) {
            $existingQuery = Get-Content -Path $KqlPath -Raw
            if ($existingQuery.Trim() -eq $Query.Trim()) {
                return $false # No change needed
            }
        }
        
        if (-not $DryRun) {
            # Ensure directory exists
            $directory = Split-Path $KqlPath -Parent
            if (-not (Test-Path $directory)) {
                New-Item -ItemType Directory -Path $directory -Force | Out-Null
            }
            
            Set-Content -Path $KqlPath -Value $Query -Encoding UTF8
        }
        
        return $true # File was updated
    }
    catch {
        Write-Host "❌ Failed to update KQL file: $kqlPath" -ForegroundColor Red
        Write-Host "   Error: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

function Update-BicepConfig {
    param(
        [string]$RuleName,
        [object]$PortalCanon,
        [string]$OriginalDisplayName
    )
    
    Write-Host "   🔄 Using JSON-based rule management..." -ForegroundColor Cyan
    
    Write-Host "   🔄 GitOps: Syncing rule from $Environment environment to deployment configs..." -ForegroundColor Cyan
    
    # Update both dev and prod configs to maintain environment parity for deployment pipeline
    # This ensures when changes are merged to main, prod deployment will have the correct config
    foreach ($env in @("dev", "prod")) {
        Write-Host "   📝 Updating $env deployment config..." -ForegroundColor Gray
    
    $paths = Get-OrganizationPaths -OrganizationName $Organization -Environment $env
    $rulesJsonPath = "$($paths.EnvDirectory)/rules-$env.json"
        
    if ($DryRun) {
        Write-Host "   📝 Would update $rulesJsonPath" -ForegroundColor Yellow
        return
    }
        
        try {
            # Load existing rules JSON
            if (Test-Path $rulesJsonPath) {
                $existingRules = Get-Content -Path $rulesJsonPath -Raw | ConvertFrom-Json
            } else {
                $existingRules = @()
            }
            
            # Convert to ArrayList for easier manipulation
            $rulesList = [System.Collections.ArrayList]$existingRules
            
            # Create rule object from portal data
            $ruleObject = @{
                name = $RuleName
                displayName = $OriginalDisplayName
                kqlFile = "$RuleName.kql"
                severity = $PortalCanon.severity
                enabled = $PortalCanon.enabled
                frequency = $PortalCanon.frequency
                period = $PortalCanon.period
                tactics = $PortalCanon.tactics
                techniques = $PortalCanon.techniques
                createIncident = if ($PortalCanon.createIncident) { $PortalCanon.createIncident } else { $true }
                grouping = if ($PortalCanon.grouping) { $PortalCanon.grouping } else { @{ enabled = $false; matchingMethod = "AllEntities" } }
                entities = if ($PortalCanon.entities) { $PortalCanon.entities } else { @{} }
                customDetails = @{}
            }
            
            # Check if rule already exists (by name or displayName)
            $existingRuleIndex = -1
            for ($i = 0; $i -lt $rulesList.Count; $i++) {
                $rule = $rulesList[$i]
                if ($rule.name -eq $RuleObject.name -or $rule.displayName -eq $RuleObject.displayName) {
                    $existingRuleIndex = $i
                    break
                }
            }
            
            if ($existingRuleIndex -ge 0) {
                # Update existing rule
                Write-Host "   🔄 Updating existing rule at index $existingRuleIndex" -ForegroundColor Yellow
                $rulesList[$existingRuleIndex] = $ruleObject
            } else {
                # Add new rule
                Write-Host "   ➕ Adding new rule" -ForegroundColor Green
                $rulesList.Add($ruleObject) | Out-Null
                
                # For new rules, we need to add the KQL variable to Bicep
                Add-KqlVariableToBicep -RuleName $RuleName -Environment $env -Organization $Organization
            }
            
            # Save updated rules JSON
            $updatedJson = $rulesList | ConvertTo-Json -Depth 10
            Set-Content -Path $rulesJsonPath -Value $updatedJson -Encoding UTF8
            Write-Host "   💾 Saved rules JSON: $($rulesList.Count) total rules" -ForegroundColor Green
            
        } catch {
            Write-Host "   ❌ Failed to update $env rules: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}

function Add-KqlVariableToBicep {
    param([string]$RuleName, [string]$Environment, [string]$Organization)
    
    $paths = Get-OrganizationPaths -OrganizationName $Organization -Environment $Environment
    $bicepPath = $paths.BicepPath
    
    if (-not (Test-Path $bicepPath)) {
        Write-Host "   ⚠️  Bicep file not found: $bicepPath" -ForegroundColor Yellow
        return
    }
    
    $cleanName = $RuleName -replace '[^a-z0-9]', ''
    $kqlVarName = "kql$cleanName"
    $kqlFileName = "$RuleName.kql"
    
    # Read current Bicep content
    $content = Get-Content -Path $bicepPath -Raw
    
    # Check if the variable already exists
    if ($content -match "var\s+$kqlVarName\s*=") {
        Write-Host "   ✅ KQL variable $kqlVarName already exists" -ForegroundColor Green
        return
    }
    
    # Add the new KQL variable declaration
    $newKqlVar = "var $kqlVarName = loadTextContent('../kql/$Environment/$kqlFileName')"
    
    # Find insertion point (after the last existing KQL variable)
    $lines = $content -split "`n"
    $insertIndex = -1
    
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match "^var\s+kql\w+\s*=\s*loadTextContent") {
            $insertIndex = $i
        }
    }
    
    if ($insertIndex -ge 0) {
        # Insert the new variable after the last KQL variable
        $lines = [System.Collections.ArrayList]$lines
        $lines.Insert($insertIndex + 1, $newKqlVar)
        
        # Also add to the kqlLookup object
        $lookupEntry = "  '$kqlFileName': $kqlVarName"
        
        # Find the kqlLookup section and add the new entry
        for ($i = 0; $i -lt $lines.Count; $i++) {
            if ($lines[$i] -match "^var\s+kqlLookup\s*=\s*\{") {
                # Find the closing brace and insert before it
                for ($j = $i + 1; $j -lt $lines.Count; $j++) {
                    if ($lines[$j] -match "^\}") {
                        $lines.Insert($j, $lookupEntry)
                        break
                    }
                }
                break
            }
        }
        
        # Write the updated content
        $updatedContent = $lines -join "`n"
        Set-Content -Path $bicepPath -Value $updatedContent -Encoding UTF8
        Write-Host "   ✅ Added KQL variable $kqlVarName to Bicep" -ForegroundColor Green
    } else {
        Write-Host "   ❌ Could not find insertion point for KQL variable" -ForegroundColor Red
    }
}

# Normalize function (simplified - only fixes BCP238 errors)
function Normalize-RulesArray {
    param([string]$text)
    # Fix any "}, \n  {" patterns that might cause BCP238 errors
    $fixed = $text -replace '\},\s*\n\s*\{', '}, {'
    # Ensure consistent line endings
    $fixed = $fixed -replace '\r\n', "`n" -replace '\r', "`n"
    return $fixed
}

function Find-MissingRulesInProd {
    param(
        [array]$DevRules,
        [string]$Organization
    )
    
    Write-Host "🔍 Checking for rules missing in prod environment..." -ForegroundColor Cyan
    
    try {
        # Get prod Sentinel rules
        $prodRules = az sentinel alert-rule list `
            --resource-group "sentinel-ws-prod" `
            --workspace-name "sentinel-rg-prod" `
            --query "[?kind=='Scheduled'].displayName" `
            -o tsv
        
        $prodRuleNames = @()
        if ($prodRules) {
            $prodRuleNames = $prodRules -split "`n" | Where-Object { $_ -and $_.Trim() }
        }
        
        Write-Host "   📊 Found $($prodRuleNames.Count) rules in prod Sentinel" -ForegroundColor Gray
        
        # Find dev rules missing from prod
        $missingRules = @()
        foreach ($devRule in $DevRules) {
            $ruleName = $devRule.displayName
            if ($ruleName -notin $prodRuleNames) {
                $missingRules += $devRule
                Write-Host "   🚨 Missing in prod: $ruleName" -ForegroundColor Red
            } else {
                Write-Host "   ✅ Found in prod: $ruleName" -ForegroundColor Green
            }
        }
        
        if ($missingRules.Count -gt 0) {
            Write-Host "🎯 GitOps Action Required: $($missingRules.Count) rules need to be deployed to prod" -ForegroundColor Yellow
            Write-Host "   This will trigger automatic PR creation for prod deployment..." -ForegroundColor Gray
            
            # TODO: Add automatic PR creation logic here
            # For now, just flag that action is needed
            return $missingRules
        } else {
            Write-Host "✅ All dev rules exist in prod - no GitOps action needed" -ForegroundColor Green
            return @()
        }
        
    } catch {
        Write-Host "   ❌ Failed to check prod environment: $($_.Exception.Message)" -ForegroundColor Red
        return @()
    }
}

# Main execution
try {
    Write-Host "🚀 Sentinel Rules GitOps Sync" -ForegroundColor Green
Write-Host "📡 Fetching rules from $Environment environment ($ResourceGroup/$WorkspaceName)..." -ForegroundColor Cyan
Write-Host "🔄 Will update both dev & prod configs for deployment pipeline..." -ForegroundColor Gray
    
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
            customDetails: customDetails,
            kind: kind,
            alertRuleTemplateName: alertRuleTemplateName
        }' `
        --output json | ConvertFrom-Json
    
    if (!$rules) {
        Write-Host "❌ No rules found in Sentinel workspace" -ForegroundColor Red
        exit 1
    }
    
    Write-Host "📊 Found $($rules.Count) rules in Sentinel" -ForegroundColor Green

    # Helper: determine if a rule is vendor/built-in using metadata (scalable)
    function Test-IsVendorRule {
        param([object]$r)
        # Built-in and template-based rules expose metadata
        if ($r.kind -and ($r.kind -ne 'Scheduled')) { return $true }
        if ($r.alertRuleTemplateName) { return $true }
        return $false
    }

    function Convert-ToTimeSpan {
        param([string]$val)
        if (-not $val) { return $null }
        try {
            if ($val -match '^[0-9]{1,2}:[0-9]{2}:[0-9]{2}$') {
                return [TimeSpan]::Parse($val)
            }
            if ($val -match '^PT([0-9]+)M$') {
                return [TimeSpan]::FromMinutes([int]$matches[1])
            }
            return [TimeSpan]::Parse($val)
        } catch {
            Write-Host "Warning: Could not parse timespan '$val'" -ForegroundColor Yellow
            return $null
        }
    }

    function Get-EntityMappings {
        param([array]$mappings)
        # Return entity mappings as-is from Azure Sentinel - no conversion needed
        if ($mappings -and $mappings.Count -gt 0) {
            return $mappings
        }
        return @()
    }

    function Get-CompleteRuleDetails {
        param([string]$ResourceGroup, [string]$WorkspaceName, [string]$RuleId)
        
        # Use REST API to get complete rule details including entity mappings
        $subscriptionId = (az account show --query id -o tsv).Trim()
        if ([string]::IsNullOrEmpty($subscriptionId)) {
            Write-Host "Error: Could not get subscription ID" -ForegroundColor Red
            return $null
        }
        
        $uri = "/subscriptions/$subscriptionId/resourceGroups/$ResourceGroup/providers/Microsoft.OperationalInsights/workspaces/$WorkspaceName/providers/Microsoft.SecurityInsights/alertRules/$RuleId"
        
        try {
            $apiVersion = "api-version=2023-02-01"
            $fullUrl = $uri + "?" + $apiVersion
            
            # Use Invoke-Expression to avoid PowerShell argument parsing issues
            $cmd = "az rest --method GET --url `"$fullUrl`""
            $result = Invoke-Expression $cmd | ConvertFrom-Json
            return $result.properties
        } catch {
            Write-Host "Warning: Could not get complete details for rule $RuleId" -ForegroundColor Yellow
            Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
            return $null
        }
    }

    # Filter custom rules (exclude vendor/built-in rules)
    $customRules = $rules | Where-Object { -not (Test-IsVendorRule -r $_) }
    
    Write-Host "📋 Processing $($customRules.Count) custom rules (excluding vendor rules)" -ForegroundColor Cyan

    if ($RuleName) {
        $customRules = $customRules | Where-Object { $_.displayName -eq $RuleName }
        if ($customRules.Count -eq 0) {
            Write-Host "❌ Rule '$RuleName' not found or is a vendor rule" -ForegroundColor Red
            exit 1
        }
    }

    # Check for deleted rules (only when processing all rules, not when filtering to specific rule)
    if (-not $RuleName) {
        Find-DeletedRules -PortalRules $customRules -Organization $Organization
    } else {
        Write-Host "`n🎯 Processing specific rule: $RuleName (skipping deletion check)" -ForegroundColor Cyan
    }

    # Process each custom rule
    $updatedCount = 0
    foreach ($rule in $customRules) {
        Write-Host "`n🔄 Processing: $($rule.displayName)" -ForegroundColor Cyan
        
        # Get complete rule details including entity mappings
        $completeRule = Get-CompleteRuleDetails -ResourceGroup $ResourceGroup -WorkspaceName $WorkspaceName -RuleId $rule.name
        if (-not $completeRule) {
            Write-Host "   ⚠️ Skipping rule due to API error" -ForegroundColor Yellow
            continue
        }
        
        # Use complete rule data instead of CLI data
        $rule = $completeRule
        
        # Normalize rule name
        $cleanRuleName = Get-RuleNameFromDisplay -DisplayName $rule.displayName
        
        # Update KQL files for both environments (maintains dev/prod parity for GitOps)
        $kqlChanged = $false
        foreach ($env in @("dev", "prod")) {
            $paths = Get-OrganizationPaths -OrganizationName $Organization -Environment $env
            $kqlPath = "$($paths.KqlDirectory)/$cleanRuleName.kql"
            
            $envKqlChanged = Update-KqlFile -KqlPath $kqlPath -Query $rule.query
            if ($envKqlChanged) {
                Write-Host "   ✅ Updated $env KQL file" -ForegroundColor Green
                $kqlChanged = $true
            } else {
                Write-Host "   ✅ $env KQL unchanged - skipping update" -ForegroundColor Green
            }
        }
        
        # Build canonical representation from portal
        $portalCanon = @{
            severity = $rule.severity
            enabled = $rule.enabled
            frequency = Convert-TimeSpanToISO8601 -TimeSpanValue $rule.queryFrequency
            period = Convert-TimeSpanToISO8601 -TimeSpanValue $rule.queryPeriod
            tactics = $rule.tactics
            techniques = $rule.techniques
            createIncident = $rule.createIncident
            grouping = @{
                enabled = $rule.groupingEnabled
                matchingMethod = if ($rule.groupingMethod) { $rule.groupingMethod } else { 'AllEntities' }
            }
            entities = Get-EntityMappings -mappings $rule.entityMappings
        }
        
        # Check if metadata changed (simplified comparison)
        $metadataChanged = $kqlChanged -or $ForceSync
        
        # Update Bicep only if metadata changed or force
        if ($metadataChanged -or $ForceSync) {
            Update-BicepConfig -RuleName $cleanRuleName -PortalCanon $portalCanon -OriginalDisplayName $rule.displayName
        } else {
            Write-Host "   ✅ Metadata unchanged - skipping Bicep update" -ForegroundColor Green
        }
        
        $updatedCount++
    }

    # Check for missing rules in prod environment (GitOps drift detection)
    Write-Host ""
    $missingInProd = Find-MissingRulesInProd -DevRules $customRules -Organization $Organization
    
    Write-Host "`n🎉 Sync completed!" -ForegroundColor Green
    Write-Host "📊 Rules processed: $updatedCount" -ForegroundColor Gray
    
    if ($missingInProd.Count -gt 0) {
        Write-Host "🚨 GitOps Alert: $($missingInProd.Count) rules need deployment to prod" -ForegroundColor Yellow
        foreach ($rule in $missingInProd) {
            Write-Host "   - $($rule.displayName)" -ForegroundColor Yellow
        }
        Write-Host "   💡 Create a PR to deploy these rules to production" -ForegroundColor Cyan
    }
    
    if ($CreateBranch) {
        Write-Host "📝 Branch creation not implemented in clean version" -ForegroundColor Yellow
    }

} catch {
    Write-Host "❌ Sync failed: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Red
    exit 1
}
