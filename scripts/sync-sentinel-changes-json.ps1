#!/usr/bin/env pwsh

# Simplified sync script using JSON approach
# This eliminates all the complex Bicep parsing and is much more reliable

param(
    [Parameter(Mandatory)]
    [string]$Organization,
    
    [Parameter(Mandatory)]
    [ValidateSet("dev", "prod")]
    [string]$Environment,
    
    [switch]$DryRun
)

function Get-OrganizationPaths {
    param([string]$OrganizationName, [string]$Environment)
    
    $orgRoot = "organizations/$OrganizationName"
    
    return @{
        EnvDirectory = "$orgRoot/env"
        KqlDirectory = "$orgRoot/kql/$Environment"
        BicepPath = "$orgRoot/env/deploy-$Environment.bicep"
        RulesJsonPath = "$orgRoot/env/rules-$Environment.json"
    }
}

function Get-CleanRuleName {
    param([string]$DisplayName)
    return $DisplayName -replace '[^a-zA-Z0-9\s]', '' -replace '\s+', ' '
}

function Sync-Rule {
    param(
        [string]$RuleName,
        [object]$PortalCanon,
        [string]$OriginalDisplayName,
        [string]$Organization,
        [string]$Environment,
        [bool]$DryRun
    )
    
    Write-Host "`n🔄 Processing rule: $OriginalDisplayName" -ForegroundColor Cyan
    
    $paths = Get-OrganizationPaths -OrganizationName $Organization -Environment $Environment
    
    # Find the corresponding KQL file for this rule
    $cleanDisplayName = Get-CleanRuleName -DisplayName $OriginalDisplayName
    $generatedRuleName = $cleanDisplayName.ToLower() -replace '[^a-z0-9\s]', '' -replace '\s+', '-'
    
    # Try to find existing KQL file that matches this rule
    $kqlFiles = Get-ChildItem "$($paths.KqlDirectory)/*.kql"
    $matchedKqlFile = $null
    
    # First try exact match
    $exactMatch = $kqlFiles | Where-Object { $_.BaseName -eq $generatedRuleName }
    if ($exactMatch) {
        $matchedKqlFile = $exactMatch
    } else {
        # Try fuzzy matching based on keywords in the display name
        $keywords = $cleanDisplayName.ToLower() -split '\s+' | Where-Object { $_.Length -gt 2 }
        foreach ($kqlFile in $kqlFiles) {
            $basename = $kqlFile.BaseName.ToLower()
            $matchCount = 0
            foreach ($keyword in $keywords) {
                if ($basename -like "*$keyword*") { $matchCount++ }
            }
            # If we match most keywords, use this file
            if ($matchCount -ge [Math]::Max(1, $keywords.Count - 1)) {
                $matchedKqlFile = $kqlFile
                break
            }
        }
    }
    
    # Use the matched KQL file name or fallback to generated name
    if ($matchedKqlFile) {
        $generatedRuleName = $matchedKqlFile.BaseName
        $kqlFileName = $matchedKqlFile.Name
        Write-Host "   ✅ Found matching KQL file: $($matchedKqlFile.Name)" -ForegroundColor Green
    } else {
        $kqlFileName = "$generatedRuleName.kql"
        Write-Host "   ⚠️  No matching KQL file found, using generated name: $kqlFileName" -ForegroundColor Yellow
    }
    
    # Create rule object for JSON
    $ruleObject = @{
        name = $generatedRuleName
        displayName = $OriginalDisplayName
        kqlFile = $kqlFileName
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
    
    if ($DryRun) {
        Write-Host "📝 Would update rules JSON:" -ForegroundColor Yellow
        Write-Host "   File: $($paths.RulesJsonPath)" -ForegroundColor Gray
        Write-Host "   Rule: $($ruleObject | ConvertTo-Json -Depth 10)" -ForegroundColor Gray
        return
    }
    
    # Update rules JSON
    Update-RulesJson -RulesJsonPath $paths.RulesJsonPath -RuleObject $ruleObject -Organization $Organization -Environment $Environment
}

function Update-RulesJson {
    param(
        [string]$RulesJsonPath,
        [object]$RuleObject,
        [string]$Organization,
        [string]$Environment
    )
    
    # Load existing rules JSON
    if (Test-Path $RulesJsonPath) {
        $existingRules = Get-Content -Path $RulesJsonPath -Raw | ConvertFrom-Json
        Write-Host "   📊 Loaded existing rules: $($existingRules.Count)" -ForegroundColor Gray
    } else {
        $existingRules = @()
        Write-Host "   📊 Creating new rules file" -ForegroundColor Gray
    }
    
    # Convert to ArrayList for easier manipulation
    $rulesList = [System.Collections.ArrayList]$existingRules
    
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
        $rulesList[$existingRuleIndex] = $RuleObject
    } else {
        # Add new rule
        Write-Host "   ➕ Adding new rule" -ForegroundColor Green
        $rulesList.Add($RuleObject) | Out-Null
    }
    
    # Save updated rules JSON
    $updatedJson = $rulesList | ConvertTo-Json -Depth 10
    Set-Content -Path $RulesJsonPath -Value $updatedJson -Encoding UTF8
    Write-Host "   💾 Saved rules JSON: $($rulesList.Count) total rules" -ForegroundColor Green
    
    # Regenerate Bicep file
    Write-Host "   🔧 Regenerating Bicep file..." -ForegroundColor Cyan
    $generateResult = & pwsh "scripts/generate-bicep-from-json.ps1" -Organization $Organization -Environment $Environment
    if ($LASTEXITCODE -eq 0) {
        Write-Host "   ✅ Bicep file regenerated successfully" -ForegroundColor Green
    } else {
        Write-Host "   ❌ Failed to regenerate Bicep file" -ForegroundColor Red
        Write-Host $generateResult -ForegroundColor Red
    }
}

function Test-AddRule {
    param([string]$Organization, [string]$Environment)
    
    Write-Host "`n🧪 Testing: Add CustomRule3 to $Organization ($Environment)" -ForegroundColor Magenta
    
    # Create test rule object (simulates what would come from Azure Sentinel)
    $testPortalRule = @{
        severity = "High"
        enabled = $true
        frequency = "PT5M"
        period = "PT10M"
        tactics = @("InitialAccess", "CredentialAccess")
        techniques = @("T1078", "T1110")
        createIncident = $true
        grouping = @{
            enabled = $false
            matchingMethod = "AllEntities"
        }
        entities = @{
            accountFullName = "UserPrincipalName"
            ipAddress = "IPAddress"
        }
    }
    
    # Create test KQL file
    $paths = Get-OrganizationPaths -OrganizationName $Organization -Environment $Environment
    $testKqlPath = "$($paths.KqlDirectory)/customrule3.kql"
    $testKqlContent = @"
SecurityEvent
| where EventID == 4625
| where SubStatus == '0xC000006A'
| summarize count() by Account, Computer
| where count_ >= 5
"@
    
    Write-Host "📁 Creating test KQL file: $testKqlPath" -ForegroundColor Gray
    Set-Content -Path $testKqlPath -Value $testKqlContent -Encoding UTF8
    
    try {
        # Sync the test rule
        Sync-Rule -RuleName "customrule3" -PortalCanon $testPortalRule -OriginalDisplayName "CustomRule3" -Organization $Organization -Environment $Environment -DryRun $false
        
        # Verify results
        $paths = Get-OrganizationPaths -OrganizationName $Organization -Environment $Environment
        $rulesJson = Get-Content -Path $paths.RulesJsonPath -Raw | ConvertFrom-Json
        
        Write-Host "`n📊 Verification Results:" -ForegroundColor Cyan
        Write-Host "   Total rules in JSON: $($rulesJson.Count)" -ForegroundColor Gray
        
        $hasCustomRule1 = $rulesJson | Where-Object { $_.name -eq "customrule1" }
        $hasCustomRule2 = $rulesJson | Where-Object { $_.name -eq "customrule2" }
        $hasCustomRule3 = $rulesJson | Where-Object { $_.name -eq "customrule3" }
        
        Write-Host "   customrule1 preserved: $($hasCustomRule1 -ne $null)" -ForegroundColor $(if ($hasCustomRule1) { "Green" } else { "Red" })
        Write-Host "   customrule2 preserved: $($hasCustomRule2 -ne $null)" -ForegroundColor $(if ($hasCustomRule2) { "Green" } else { "Red" })
        Write-Host "   customrule3 added: $($hasCustomRule3 -ne $null)" -ForegroundColor $(if ($hasCustomRule3) { "Green" } else { "Red" })
        
        # Test Bicep compilation
        Push-Location (Split-Path $paths.BicepPath)
        try {
            Write-Host "`n🔨 Testing Bicep compilation..." -ForegroundColor Yellow
            $compileResult = & az bicep build --file (Split-Path $paths.BicepPath -Leaf) --stdout 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-Host "✅ Bicep compilation successful" -ForegroundColor Green
            } else {
                Write-Host "❌ Bicep compilation failed:" -ForegroundColor Red
                Write-Host $compileResult -ForegroundColor Red
            }
        } finally {
            Pop-Location
        }
        
        if ($hasCustomRule1 -and $hasCustomRule2 -and $hasCustomRule3 -and $LASTEXITCODE -eq 0) {
            Write-Host "`n🎉 SUCCESS! JSON approach works perfectly!" -ForegroundColor Green
            Write-Host "   ✅ All existing rules preserved" -ForegroundColor Green
            Write-Host "   ✅ New rule added correctly" -ForegroundColor Green
            Write-Host "   ✅ Bicep compiles successfully" -ForegroundColor Green
        } else {
            Write-Host "`n❌ Test failed" -ForegroundColor Red
        }
        
    } finally {
        # Cleanup test KQL file but keep the JSON changes for verification
        if (Test-Path $testKqlPath) {
            Remove-Item $testKqlPath -Force
            Write-Host "🗑️  Removed test KQL file" -ForegroundColor Gray
        }
    }
}

# Main execution
Write-Host "🚀 JSON-based Sentinel Rules Sync" -ForegroundColor Green
Write-Host "Organization: $Organization" -ForegroundColor Gray
Write-Host "Environment: $Environment" -ForegroundColor Gray
Write-Host "Dry Run: $DryRun" -ForegroundColor Gray

# For now, let's test the new approach by adding CustomRule3
Test-AddRule -Organization $Organization -Environment $Environment
