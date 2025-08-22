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
    [switch]$ForceSync,

    [Parameter(Mandatory = $false)]
    [switch]$VendorRulesOnly,
    
    [Parameter(Mandatory = $false)]
    [switch]$DryRun
)

# Import configuration manager
. .\scripts\ConfigManager.ps1

# Set error action preference
$ErrorActionPreference = "Stop"

Write-Host "🔄 Starting Sentinel to Repository Sync..." -ForegroundColor Cyan
Write-Host "Resource Group: $ResourceGroup" -ForegroundColor Yellow
Write-Host "Workspace: $WorkspaceName" -ForegroundColor Yellow
Write-Host "Environment: $Environment" -ForegroundColor Yellow
Write-Host "Organization: $Organization" -ForegroundColor Yellow
Write-Host "Create Branch: $CreateBranch" -ForegroundColor Yellow
Write-Host "Force Sync: $ForceSync" -ForegroundColor Yellow
Write-Host "Vendor Rules Only: $VendorRulesOnly" -ForegroundColor Yellow
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
    
    # Remove environment prefixes like [DEV] [ORG] – (note: – is U+2013 en dash)
    $dashChar = [char]0x2013
    $cleanName = $DisplayName -replace "^\[(DEV|PROD)\]\s*\[[^\]]+\]\s*$dashChar\s*", ''
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

# Function to find rules that exist in repo but not in portal (deleted rules)
function Find-DeletedRules {
    param(
        [array]$portalRules,
        [string]$env
    )
    
    $paths = Get-OrganizationPaths -OrganizationName $Organization -Environment $env
    $bicepPath = $paths.BicepPath
    if (-not (Test-Path $bicepPath)) { return @() }
    
    $content = Get-Content -Path $bicepPath -Raw
    $deletedRules = @()
    
    # Extract all rules from bicep file
    $lines = $content -split "`n"
    $inRulesArray = $false
    $inRuleBlock = $false
    $braceLevel = 0
    $currentRule = ""
    
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]
        
        if ($line -match 'var\s+rules\s*=\s*\[') {
            $inRulesArray = $true
            continue
        }
        
        if ($inRulesArray) {
            $openBraces = ($line -split '\{').Length - 1
            $closeBraces = ($line -split '\}').Length - 1
            $braceLevel += $openBraces - $closeBraces
            
            if ($line -match '^\s*\{' -and $braceLevel -eq 1 -and -not $inRuleBlock) {
                $inRuleBlock = $true
                $currentRule = ""
            }
            
            if ($inRuleBlock) {
                $currentRule += $line + "`n"
                
                if ($braceLevel -eq 0) {
                    $inRuleBlock = $false
                    
                    # Extract rule info from bicep block
                    if ($currentRule -match "name:\s*'([^']*)'") { $ruleName = $matches[1] }
                    if ($currentRule -match "displayName:\s*'([^']*)'") { $displayName = $matches[1] }
                    
                    # Check if this rule still exists in portal
                    $portalMatch = $portalRules | Where-Object { 
                        $_.displayName -eq $displayName -or 
                        (Get-RuleNameFromDisplay -DisplayName $_.displayName) -eq $ruleName
                    }
                    
                    if (-not $portalMatch -and $displayName) {
                        $deletedRules += [PSCustomObject]@{
                            Name = $ruleName
                            DisplayName = $displayName
                            BicepBlock = $currentRule.TrimEnd("`n")
                        }
                    }
                    $currentRule = ""
                }
            }
            
            if ($line -match '^\s*\]' -and $braceLevel -eq 0) {
                $inRulesArray = $false
                break
            }
        }
    }
    
    return $deletedRules
}

# Function to remove rule from bicep file
function Remove-RuleFromBicep {
    param(
        [string]$ruleName,
        [string]$displayName,
        [string]$env
    )
    
    $paths = Get-OrganizationPaths -OrganizationName $Organization -Environment $env
    $bicepPath = $paths.BicepPath
    if (-not (Test-Path $bicepPath)) { return }
    
    $content = Get-Content -Path $bicepPath -Raw
    $kqlVarToRemove = $null
    
    # Find and extract KQL variable info BEFORE removing the rule block
    $escDisplayName = [regex]::Escape($displayName)
    $displayPat = "(?s)\{\s*name:\s*'[^']*'[^}]*displayName:\s*'$escDisplayName'[^}]*\}(?:\s*\})*(,?)"
    
    if ($content -match $displayPat) {
        $ruleBlock = $matches[0]
        if ($ruleBlock -match "kql:\s*kql([A-Za-z0-9_-]+)") {
            $kqlVarToRemove = "kql$($matches[1])"
        }
        $content = $content -replace $displayPat, ''
        # Clean up any double commas or trailing commas
        $content = $content -replace ',\s*,', ','
        $content = $content -replace ',(\s*\])', '$1'
    } else {
        # Fallback to rule name
        $escName = [regex]::Escape($ruleName)
        $namePat = "(?s)\{\s*name:\s*'$escName'[^}]*\}(?:\s*\})*(,?)"
        if ($content -match $namePat) {
            $ruleBlock = $matches[0]
            if ($ruleBlock -match "kql:\s*kql([A-Za-z0-9_-]+)") {
                $kqlVarToRemove = "kql$($matches[1])"
            }
            $content = $content -replace $namePat, ''
            $content = $content -replace ',\s*,', ','
            $content = $content -replace ',(\s*\])', '$1'
        }
    }
    
    # Remove the KQL variable declaration if we found one
    if ($kqlVarToRemove) {
        $kqlVarPattern = "var\s+$kqlVarToRemove\s*=\s*loadTextContent\('[^']*'\)\s*\n?"
        $content = $content -replace $kqlVarPattern, ''
        Write-Host "🗑️  Removed KQL variable: $kqlVarToRemove" -ForegroundColor Red
    }
    
    $content | Out-File -FilePath $bicepPath -Encoding UTF8
    Write-Host "🗑️  Removed rule from $bicepPath" -ForegroundColor Red
}

# Function to remove unused KQL file and variable
function Remove-UnusedKqlFile {
    param([string]$ruleName)
    
    # Find potential KQL files for this rule
    $paths = Get-OrganizationPaths -OrganizationName $Organization -Environment $Environment
    $kqlPattern = "$($paths.KqlDirectory)/$ruleName*.kql"
    $kqlFiles = Get-ChildItem $kqlPattern -ErrorAction SilentlyContinue
    
    foreach ($kqlFile in $kqlFiles) {
        # Check if this KQL file is still referenced in any bicep file
        $isReferenced = $false
        $paths = Get-OrganizationPaths -OrganizationName $Organization -Environment $Environment
        $bicepFiles = Get-ChildItem "$($paths.EnvDirectory)/deploy-*.bicep"
        
        foreach ($bicepFile in $bicepFiles) {
            $bicepContent = Get-Content -Path $bicepFile.FullName -Raw
            $relDir = if ($Environment -eq 'prod') { './kql/prod/' } else { './kql/dev/' }
            if ($bicepContent -match "loadTextContent\('$([regex]::Escape($relDir))$([regex]::Escape($kqlFile.Name))'\)") {
                $isReferenced = $true
                break
            }
        }
        
        if (-not $isReferenced) {
            # Remove the KQL file
            Remove-Item $kqlFile.FullName
            Write-Host "🗑️  Removed unused KQL file: $($kqlFile.Name)" -ForegroundColor Red
        }
    }
}

# Function to update KQL file
function Update-KqlFile {
    param(
        [string]$RuleName,
        [string]$Query
    )
    
    $paths = Get-OrganizationPaths -OrganizationName $Organization -Environment $Environment
    $envKqlDir = $paths.KqlDirectory
    $kqlPath = "$envKqlDir/$RuleName.kql"
    
    if ($DryRun) { 
        Write-Host "📝 Would update KQL file: $kqlPath" -ForegroundColor Yellow
        return 
    }
    
    try {
        # Ensure kql directory exists
        if (!(Test-Path $envKqlDir)) {
            New-Item -ItemType Directory -Path $envKqlDir -Force | Out-Null
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
        [object]$PortalCanon,
        [string]$OriginalDisplayName
    )
    
    $devPaths = Get-OrganizationPaths -OrganizationName $Organization -Environment "dev"
    $prodPaths = Get-OrganizationPaths -OrganizationName $Organization -Environment "prod"
    $devBicepPath = $devPaths.BicepPath
    $prodBicepPath = $prodPaths.BicepPath
    
    # Find the corresponding KQL file for this rule
    $cleanDisplayName = Get-CleanRuleName -DisplayName $OriginalDisplayName
    $generatedRuleName = $cleanDisplayName.ToLower() -replace '[^a-z0-9\s]', '' -replace '\s+', '-'
    
    # Try to find existing KQL file that matches this rule
    $paths = Get-OrganizationPaths -OrganizationName $Organization -Environment $Environment
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
        Write-Host "   Found matching KQL file: $($matchedKqlFile.Name)" -ForegroundColor Green
        
        # Try to find existing KQL variable in bicep file
        if ($Environment -eq 'prod') {
            $bicepPath = $prodBicepPath
        } else {
            $bicepPath = $devBicepPath
        }
        $generatedKqlVar = "kql$($generatedRuleName -replace '-', '')" # fallback
        
        if (Test-Path $bicepPath) {
            $bicepContent = Get-Content -Path $bicepPath -Raw
            $kqlFileName = $matchedKqlFile.Name
            if ($Environment -eq 'prod') {
                $relDir = './kql/prod/'
            } else {
                $relDir = './kql/dev/'
            }
            $varPattern = "var\s+(kql\w+)\s*=\s*loadTextContent\('$([regex]::Escape($relDir))$([regex]::Escape($kqlFileName))'\)"
            if ($bicepContent -match $varPattern) {
                $generatedKqlVar = $matches[1]
                Write-Host "   Found existing KQL variable: $generatedKqlVar" -ForegroundColor Green
            }
        }
        
        # Try to find existing rule name in bicep file
        $ruleNamePattern = "name:\s*'([^']*)'.*?displayName:\s*'([^']*)'"
        if ($bicepContent -match $ruleNamePattern) {
            $matches = [regex]::Matches($bicepContent, $ruleNamePattern, [System.Text.RegularExpressions.RegexOptions]::Singleline)
            foreach ($match in $matches) {
                $ruleDisplayName = $match.Groups[2].Value
                $ruleName = $match.Groups[1].Value
                # Check if this rule matches our current rule (handle suffixes like (T1078))
                $cleanRuleDisplayName = $ruleDisplayName -replace '\s*\([^)]*\)$', ''
                $cleanCurrentDisplayName = $OriginalDisplayName -replace '\s*\([^)]*\)$', ''
                if ($cleanRuleDisplayName -eq $cleanCurrentDisplayName) {
                    $generatedRuleName = $ruleName
                    Write-Host "   Found existing rule name: $generatedRuleName" -ForegroundColor Green
                    break
                }
            }
        }
    } else {
        Write-Host "   Warning: No matching KQL file found, using generated name: $generatedRuleName" -ForegroundColor Yellow
        $generatedKqlVar = "kql$($generatedRuleName -replace '-', '')"
    }
    
    # Use portal as the source of truth for all values
    $envSeverity = $PortalCanon.severity
    $envCreateIncident = $PortalCanon.createIncident
    $envTechniques = $PortalCanon.techniques
    $envEntities = $PortalCanon.entities
        
    # Dynamically build entities block using portal values
    $entitiesBlock = ""
    if ($envEntities -and $envEntities.psobject.Properties.Count -gt 0) {
        $entitiesBlock = "    entities: {`n"
        foreach ($prop in $envEntities.psobject.Properties) {
            $entitiesBlock += "      $($prop.Name): '$($prop.Value)'`n"
        }
        $entitiesBlock += "    }`n"
    } else {
        $entitiesBlock = "    entities: {}`n"
    }
    
    # Dynamically build grouping block using portal values
    $groupingBlock = ""
    if ($PortalCanon.grouping -and $PortalCanon.grouping.psobject.Properties.Count -gt 0) {
        $groupingBlock = "    grouping: {`n"
        foreach ($prop in $PortalCanon.grouping.psobject.Properties) {
            $val = if ($prop.Value -match '^(true|false)$') { $prop.Value } else { "'$($prop.Value)'" }
            $groupingBlock += "      $($prop.Name): $val`n"
        }
        $groupingBlock += "    }`n"
    } else {
        $groupingBlock = "    grouping: {}`n"
    }
    
    # Build tactics and techniques using portal values (properly quoted for Bicep)
    $tacticsStr = if ($PortalCanon.tactics -and $PortalCanon.tactics.Count -gt 0) { 
        ($PortalCanon.tactics | ForEach-Object { "'$_'" }) -join ', ' 
    } else { '' }
    $techniquesStr = if ($envTechniques -and $envTechniques.Count -gt 0) { 
        ($envTechniques | ForEach-Object { "'$_'" }) -join ', ' 
    } else { '' }
    
    $ruleObject = @"
  {
    name: '$generatedRuleName'
    displayName: '$OriginalDisplayName'
    kql: $generatedKqlVar
    severity: '$envSeverity'
    enabled: $($PortalCanon.enabled)
    frequency: '$($PortalCanon.frequency)'
    period: '$($PortalCanon.period)'
    tactics: [ $tacticsStr ]
    techniques: [ $techniquesStr ]
    createIncident: $(if ($envCreateIncident) { $envCreateIncident } else { 'true' })
$groupingBlock$entitiesBlock    customDetails: {
      // TODO: Sync customDetails if needed
    }
  }
"@
    
    if ($DryRun) {
        Write-Host "📝 Would update Bicep files:" -ForegroundColor Yellow
        Write-Host "   Dev: $devBicepPath" -ForegroundColor Gray
        Write-Host "   Prod: $prodBicepPath" -ForegroundColor Gray

        Write-Host "`n📄 Generated Bicep object:" -ForegroundColor Cyan
        Write-Host $ruleObject -ForegroundColor White
        return
    }
    
    try {
        # Read existing Bicep files
        $devContent = Get-Content -Path $devBicepPath -Raw
        $prodContent = Get-Content -Path $prodBicepPath -Raw
        
        # Helper to update content: replace if exists, else append to array
        function Update-Content {
            param([string]$content, [string]$ruleObj, [string]$rname)
            
            # Find rule blocks by manually parsing brace levels
            function Find-RuleBlock {
                param([string]$text, [string]$searchDisplayName, [string]$searchName)
                
                $lines = $text -split "`n"
                $inRulesArray = $false
                $inRuleBlock = $false
                $braceLevel = 0
                $ruleStartLine = -1
                $ruleEndLine = -1
                $currentRule = ""
                
                for ($i = 0; $i -lt $lines.Count; $i++) {
                    $line = $lines[$i]
                    
                    # Track if we're in the rules array
                    if ($line -match 'var\s+rules\s*=\s*\[') {
                        $inRulesArray = $true
                        continue
                    }
                    
                    if ($inRulesArray) {
                        # Count braces to track nesting
                        $openBraces = ($line -split '\{').Length - 1
                        $closeBraces = ($line -split '\}').Length - 1
                        $braceLevel += $openBraces - $closeBraces
                        
                        # Start of a rule block
                        if ($line -match '^\s*\{' -and $braceLevel -eq 1 -and -not $inRuleBlock) {
                            $inRuleBlock = $true
                            $ruleStartLine = $i
                            $currentRule = ""
                        }
                        
                        if ($inRuleBlock) {
                            $currentRule += $line + "`n"
                            
                            # End of rule block
                            if ($braceLevel -eq 0) {
                                $ruleEndLine = $i
                                $inRuleBlock = $false
                                
                                # Check if this is the rule we're looking for
                                if (($searchDisplayName -and $currentRule -match [regex]::Escape($searchDisplayName)) -or
                                    ($searchName -and $currentRule -match "name:\s*'$([regex]::Escape($searchName))'")) {
                                    return @{
                                        Found = $true
                                        StartLine = $ruleStartLine
                                        EndLine = $ruleEndLine
                                        Content = $currentRule.TrimEnd("`n")
                                    }
                                }
                                $currentRule = ""
                            }
                        }
                        
                        # End of rules array
                        if ($line -match '^\s*\]' -and $braceLevel -eq 0) {
                            $inRulesArray = $false
                            break
                        }
                    }
                }
                
                return @{ Found = $false }
            }
            
            # Try to find existing rule
            $result = Find-RuleBlock -text $content -searchDisplayName $OriginalDisplayName -searchName $rname
            
            if ($result.Found) {
                Write-Host "   Replacing existing rule (lines $($result.StartLine)-$($result.EndLine))" -ForegroundColor Yellow
                $lines = $content -split "`n"
                # Replace the rule block
                $beforeRule = ($lines[0..($result.StartLine-1)] -join "`n") + "`n"
                $afterRule = "`n" + ($lines[($result.EndLine+1)..($lines.Count-1)] -join "`n")
                return $beforeRule + $ruleObj + $afterRule
            } else {
                Write-Host "   Adding new rule to array" -ForegroundColor Yellow
                
                # Always generate KQL variable declarations for all KQL files
                # This ensures both dev and prod Bicep files have the necessary variables

                # Generate KQL variable declarations for rules that exist in portal
                $kqlVarDeclarations = ""
                $paths = Get-OrganizationPaths -OrganizationName $Organization -Environment $Environment

                # Only generate KQL variables for rules that actually exist in the portal
                foreach ($portalRule in $rules) {
                    $ruleName = Get-RuleNameFromDisplay -DisplayName $portalRule.displayName
                    $kqlVarName = "kql$($ruleName -replace '[^a-zA-Z0-9]', '')"
                    $relDir = if ($Environment -eq 'prod') { './kql/prod/' } else { './kql/dev/' }
                    $kqlVarDeclarations += "var $kqlVarName = loadTextContent('$relDir$($ruleName).kql')`n"
                }

                # Check if this is the first rule being added (no existing rules)
                $isFirstRule = $content -match "var rules = \[\s*// Rules will be populated by sync script\s*\]"

                if ($isFirstRule) {
                    # Replace the placeholder comment with actual KQL variable declarations
                    $content = $content -replace "// KQL variables will be populated by sync script", $kqlVarDeclarations.TrimEnd("`n")
                } else {
                    # Check if KQL variable declarations already exist, if not add them
                    $hasKqlVars = $content -match "var kql\w+\s*=\s*loadTextContent"
                    if (-not $hasKqlVars -and $kqlVarDeclarations) {
                        # Find the first rule definition and insert KQL variables before it
                        $rulePattern = "var rules = \["
                        if ($content -match $rulePattern) {
                            $kqlVarsWithNewline = $kqlVarDeclarations.TrimEnd("`n") + "`n`n"
                            $content = $content -replace $rulePattern, "$kqlVarsWithNewline$&"
                        }
                    }
                }
                
                # Find the end of the rules array and insert before the closing bracket
                if ($content -match '(?s)(.*)(\n\s*\])') {
                    $beforeEnd = $matches[1]
                    $endPart = $matches[2]
                    # Check if we need a comma
                    $needsComma = $beforeEnd -match '\}\s*$'
                    $comma = if ($needsComma) { ',' } else { '' }
                    return "$beforeEnd$comma`n$ruleObj$endPart"
                }
            }
            
            return $content
        }
        
        # Update BOTH dev and prod Bicep files to keep environments in sync
        # This ensures that when PRs are merged, prod deployments have the latest rules

        # Update DEV Bicep file with dev KQL variables
        $devContent = Update-Content -content $devContent -ruleObj $ruleObject -rname $generatedRuleName
        $devContent | Out-File -FilePath $devBicepPath -Encoding UTF8
        Write-Host "✅ Updated DEV Bicep file for rule: $generatedRuleName" -ForegroundColor Green

        # Update PROD Bicep file with prod KQL variables
        # Temporarily change environment context for prod file update
        $originalEnvironment = $Environment
        $Environment = "prod"
        $prodContent = Update-Content -content $prodContent -ruleObj $ruleObject -rname $generatedRuleName
        $prodContent | Out-File -FilePath $prodBicepPath -Encoding UTF8
        Write-Host "✅ Updated PROD Bicep file for rule: $generatedRuleName" -ForegroundColor Green
        $Environment = $originalEnvironment
        
    }
    catch {
        Write-Host "❌ Failed to update Bicep files for rule: $RuleName" -ForegroundColor Red
        Write-Host "   Error: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Main execution
try {
    Write-Host "Fetching rules from Sentinel..." -ForegroundColor Cyan
    
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
            if ($val -match '^P') {
                return [System.Xml.XmlConvert]::ToTimeSpan($val)
            }
            return [TimeSpan]::Parse($val)
        } catch { return $null }
    }

    function Convert-ToIso8601Duration {
        param([TimeSpan]$ts)
        if ($null -eq $ts) { return $null }
        # Hours precision is enough for scheduled rules; include minutes if needed
        if ($ts.Minutes -eq 0 -and $ts.Seconds -eq 0) {
            return "PT$($ts.Hours)H"
        }
        return [System.Xml.XmlConvert]::ToString($ts)
    }

    function Get-SubscriptionId {
        if ($env:AZURE_SUBSCRIPTION_ID -and $env:AZURE_SUBSCRIPTION_ID.Trim()) { return $env:AZURE_SUBSCRIPTION_ID }
        try { return (az account show --query id -o tsv).Trim() } catch { return '' }
    }

    # Removed unused hashing/JSON helpers

    function Canonicalize-Shallow {
        param($obj)
        if ($null -eq $obj) { return '' }
        # Hashtable or IDictionary
        if ($obj -is [hashtable] -or $obj -is [System.Collections.IDictionary]) {
            $pairs = @()
            foreach ($k in ($obj.Keys | Sort-Object)) {
                $v = $obj[$k]
                if ($v -is [array]) { $v = ($v -join ',') }
                $pairs += ("$k=$v")
            }
            return ($pairs -join ',')
        }
        # PSCustomObject
        if ($obj -is [psobject] -and $obj.psobject.Properties.Count -gt 0) {
            $pairs = @()
            foreach ($p in ($obj.psobject.Properties.Name | Sort-Object)) {
                $val = $obj.$p
                if ($val -is [array]) { $val = ($val -join ',') }
                $pairs += ("$p=$val")
            }
            return ($pairs -join ',')
        }
        # Array
        if ($obj -is [array]) { return ($obj -join ',') }
        # Fallback to string
        return ("" + $obj)
    }

    function Normalize-ArrayText {
        param([object]$arr)
        if (-not $arr) { return @() }
        return @($arr | ForEach-Object { ("" + $_).Trim() } | Sort-Object -Unique)
    }

    function Get-CanonicalFromPortal {
        param([object]$rule, [hashtable]$entities, [string]$env)
        $freqIso = Convert-ToIso8601Duration (Convert-ToTimeSpan ("" + $rule.queryFrequency))
        $perIso  = Convert-ToIso8601Duration (Convert-ToTimeSpan ("" + $rule.queryPeriod))

        # Build entities as a whole mapping (safely empty if none)
        $entitiesMap = @{}
        if ($entities) {
            foreach ($k in $entities.Keys) { $entitiesMap[$k] = ("" + $entities[$k]) }
        }

        # Build grouping as a whole object (prefer full detail later)
        $groupingObj = [pscustomobject]@{}
        if ($rule.groupingEnabled -ne $null) { $groupingObj | Add-Member enabled ("" + $rule.groupingEnabled).ToLower() }
        if ($rule.groupingMethod)          { $groupingObj | Add-Member matchingMethod ("" + $rule.groupingMethod) }

        [pscustomobject]@{
            displayName       = Get-CleanRuleName -DisplayName $rule.displayName
            severity          = ("" + $rule.severity)
            enabled           = ("" + $rule.enabled).ToLower()
            frequency         = $freqIso
            period            = $perIso
            tactics           = (Normalize-ArrayText $rule.tactics)
            techniques        = (Normalize-ArrayText $rule.techniques)
            createIncident    = ("" + $rule.createIncident).ToLower()
            grouping          = $groupingObj
            entities          = [pscustomobject]$entitiesMap
            kql               = ("" + $rule.query).Trim()
        }
    }

    function Get-CanonicalFromRepo {
        param([string]$displayName, [string]$cleanName, [string]$env)
        $paths = Get-OrganizationPaths -OrganizationName $Organization -Environment $env
        $bicepPath = $paths.BicepPath
        if (-not (Test-Path $bicepPath)) { return $null }
        $content = Get-Content -Path $bicepPath -Raw

        # Use the same brace-counting approach as deletion logic for consistency
        $lines = $content -split "`n"
        $inRulesArray = $false
        $inRuleBlock = $false
        $braceLevel = 0
        $ruleStartLine = -1
        $ruleEndLine = -1
        $currentRule = ""
        $block = $null
        
        for ($i = 0; $i -lt $lines.Count; $i++) {
            $line = $lines[$i]
            
            # Track if we're in the rules array
            if ($line -match 'var\s+rules\s*=\s*\[') {
                $inRulesArray = $true
                continue
            }
            
            if ($inRulesArray) {
                # Count braces to track nesting
                $openBraces = ($line -split '\{').Length - 1
                $closeBraces = ($line -split '\}').Length - 1
                $braceLevel += $openBraces - $closeBraces
                
                # Start of a rule block
                if ($line -match '^\s*\{' -and $braceLevel -eq 1 -and -not $inRuleBlock) {
                    $inRuleBlock = $true
                    $ruleStartLine = $i
                    $currentRule = ""
                }
                
                if ($inRuleBlock) {
                    $currentRule += $line + "`n"
                    
                    # End of rule block
                    if ($braceLevel -eq 0) {
                        $ruleEndLine = $i
                        $inRuleBlock = $false
                        
                        # Check if this is the rule we're looking for
                        # Extract display name from current rule block
                        $currentDisplayName = ""
                        if ($currentRule -match "displayName:\s*'([^']*)'") {
                            $currentDisplayName = $matches[1]
                        }
                        
                        # Check if this is the rule we're looking for
                        $cleanCurrentDisplayName = $currentDisplayName -replace '\s*\([^)]*\)$', ''
                        $cleanTargetDisplayName = $displayName -replace '\s*\([^)]*\)$', ''
                        
                        if ($cleanCurrentDisplayName -eq $cleanTargetDisplayName) {
                            $block = $currentRule.TrimEnd("`n")
                            break
                        }
                        $currentRule = ""
                    }
                }
                
                # End of rules array
                if ($line -match '^\s*\]' -and $braceLevel -eq 0) {
                    $inRulesArray = $false
                    break
                }
            }
        }
        
        if (-not $block) { return $null }
        
        # Helper function to extract values with better regex patterns
        function m($r) { 
            if ($block -match $r) { 
                return $matches[1] 
            } else { 
                return '' 
            } 
        }
        
        function parseList($r) {
            $raw = m $r
            if ([string]::IsNullOrWhiteSpace($raw)) { return @() }
            $items = @()
            # Handle both single quotes and no quotes
            $parts = $raw -split ','
            foreach ($part in $parts) {
                $x = ($part -replace "'", '').Trim()
                if ($x) { $items += $x }
            }
            return (@($items) | Sort-Object -Unique)
        }
        
        # Extract basic properties with more robust patterns
        $severity = m "severity:\s*'([^']*)'"
        $enabled  = m "enabled:\s*(true|false)"
        $freqRaw  = m "frequency:\s*'([^']*)'"
        $perRaw   = m "period:\s*'([^']*)'"
        $inc      = m "createIncident:\s*(true|false)"
        # Grouping block: parse all key: value pairs (booleans/strings)
        $grpBlock = $null
        $groupingMap = @{}
        if ($block -match "(?s)grouping:\s*\{(.*?)\}") { $grpBlock = $matches[1] }
        if ($grpBlock) {
            foreach ($mm in [regex]::Matches($grpBlock, "(?m)^\s*([A-Za-z0-9_]+):\s*(true|false|'[^']*')")) {
                $key = $mm.Groups[1].Value
                $val = $mm.Groups[2].Value
                if ($val -match "^'") { $val = $val.Trim("'") } else { $val = $val.ToLower() }
                $groupingMap[$key] = $val
            }
        }
        # Entities block -> extract using proper brace matching
        $entitiesMap = @{}
        
        # Find the start of entities block
        if ($block -match "entities:\s*\{") {
            $entitiesStart = $block.IndexOf($matches[0])
            if ($entitiesStart -ge 0) {
                # Find the matching closing brace for entities
                $substring = $block.Substring($entitiesStart)
                $braceCount = 0
                $entitiesEnd = -1
                $foundStart = $false
                
                for ($i = 0; $i -lt $substring.Length; $i++) {
                    $char = $substring[$i]
                    if ($char -eq '{') {
                        $braceCount++
                        $foundStart = $true
                    } elseif ($char -eq '}') {
                        $braceCount--
                        if ($foundStart -and $braceCount -eq 0) {
                            $entitiesEnd = $i
                            break
                        }
                    }
                }
                
                if ($entitiesEnd -gt 0) {
                    $entitiesContent = $substring.Substring(0, $entitiesEnd + 1)
                    # Extract key: 'value' pairs from the entities content
                    $entityMatches = [regex]::Matches($entitiesContent, "([A-Za-z0-9_]+):\s*'([^']*)'")
                    foreach ($match in $entityMatches) {
                        $entitiesMap[$match.Groups[1].Value] = $match.Groups[2].Value
                    }
                }
            }
        }
        $tacticsArr    = parseList "tactics:\s*\[([^\]]*)\]"
        $techniquesArr = parseList "techniques:\s*\[([^\]]*)\]"
        $freqIso  = Convert-ToIso8601Duration (Convert-ToTimeSpan $freqRaw)
        $perIso   = Convert-ToIso8601Duration (Convert-ToTimeSpan $perRaw)
        # Resolve KQL file by following the kql variable used in the rule block
        $kqlVar   = m "kql:\s*kql([A-Za-z0-9_-]+)"
        $kqlFile  = ''
        if ($kqlVar) {
            $varPat = "(?m)^\s*var\s+kql$kqlVar\s*=\s*loadTextContent\('\./kql/(dev|prod)/([^']+)'\)"
            if ($content -match $varPat) { $kqlFile = $matches[2] }
        }
        $paths = Get-OrganizationPaths -OrganizationName $Organization -Environment $Environment
        $kqlPath  = if ($kqlFile) { "$($paths.KqlDirectory)/$kqlFile" } else { "$($paths.KqlDirectory)/$cleanName.kql" }
        $kqlText  = if (Test-Path $kqlPath) { (Get-Content -Path $kqlPath -Raw).Trim() } else { '' }
        [pscustomobject]@{
            displayName       = Get-CleanRuleName -DisplayName $displayName
            severity          = $severity
            enabled           = $enabled
            frequency         = $freqIso
            period            = $perIso
            tactics           = $tacticsArr
            techniques        = $techniquesArr
            createIncident    = $inc
            grouping          = [pscustomobject]$groupingMap
            entities          = [pscustomobject]$entitiesMap
            kql               = $kqlText
        }
    }

    function Compare-Canon {
        param($repo, $portal)
        $diffs = @()
        if ($null -eq $repo) { return @('rule: not present in repo -> will be added') }
        function Make-Diff([string]$key, $rv, $pv) {
            if ($rv -is [array]) { $rv = ($rv -join ',') }
            if ($pv -is [array]) { $pv = ($pv -join ',') }
            # Skip diffs when portal value is missing/unknown
            if ($null -eq $pv -or ($pv -is [string] -and [string]::IsNullOrWhiteSpace($pv))) { return $null }
            # For grouping/entities, skip when portal canonical has no concrete values
            if (($key -eq 'grouping' -or $key -eq 'entities') -and ($pv -is [string]) -and ($pv -notmatch '=[^,]')) { return $null }
            if ($rv -ne $pv) { return "$("$key"): repo=$rv -> portal=$pv" }
            return $null
        }
        $pairs = @(
            @{ k='severity';          r=$repo.severity;        p=$portal.severity },
            @{ k='enabled';           r=$repo.enabled;         p=$portal.enabled },
            @{ k='frequency';         r=$repo.frequency;       p=$portal.frequency },
            @{ k='period';            r=$repo.period;          p=$portal.period },
            @{ k='tactics';           r=$repo.tactics;         p=$portal.tactics },
            @{ k='techniques';        r=$repo.techniques;      p=$portal.techniques },
            @{ k='createIncident';    r=$repo.createIncident;  p=$portal.createIncident },
            @{ k='grouping';          r=(Canonicalize-Shallow $repo.grouping);  p=(Canonicalize-Shallow $portal.grouping) },
            @{ k='entities';          r=(Canonicalize-Shallow $repo.entities);  p=(Canonicalize-Shallow $portal.entities) },
            @{ k='kql';               r=$repo.kql;            p=$portal.kql }
        )
        foreach ($pair in $pairs) {
            $d = Make-Diff $pair.k $pair.r $pair.p
            if ($d) { $diffs += $d }
        }
        return $diffs
    }
    
    # Filter rules based on parameters
    if ($VendorRulesOnly) {
        $originalCount = $rules.Count
        $rules = $rules | Where-Object { Test-IsVendorRule $_ }
        $filteredCount = $rules.Count
        Write-Host "Filtered to vendor rules only: $originalCount -> $filteredCount vendor rules" -ForegroundColor Yellow
    } else {
        # Default: exclude vendor rules (custom rules only)
        $originalCount = $rules.Count
        $rules = $rules | Where-Object { -not (Test-IsVendorRule $_) }
        $filteredCount = $rules.Count
        Write-Host "Filtered out vendor rules: $originalCount -> $filteredCount custom rules" -ForegroundColor Yellow
    }
    
    # Ensure we keep all distinct rules from the portal (no dedup here)
    # This allows the repo to reflect the exact set of rules present in the environment.
    
    # Keep a copy to show available rules if a specific name isn't found
    $candidateRules = $rules

    # Filter by specific rule if provided
    if ($RuleName) {
        $escaped = [regex]::Escape($RuleName)
        $normalizedRequested = Get-RuleNameFromDisplay -DisplayName $RuleName
        $rules = $rules | Where-Object {
            ($_.name -eq $RuleName) -or
            ($_.displayName -eq $RuleName) -or
            ($_.displayName -match $escaped) -or
            ((Get-RuleNameFromDisplay -DisplayName $_.displayName) -eq $normalizedRequested)
        }
        if (!$rules) {
            Write-Host "❌ Rule '$RuleName' not found in Sentinel" -ForegroundColor Red
            Write-Host "   Available rules:" -ForegroundColor Gray
            $candidateRules | ForEach-Object { Write-Host "   - $($_.displayName)" -ForegroundColor Gray }
            exit 1
        }
        Write-Host "🎯 Syncing specific rule: $RuleName" -ForegroundColor Yellow
    }
    
    $updatedCount = 0
    $allChanges = @()
    $deletedRules = @()
    
    # Check for deleted rules (rules in repo but not in portal)
    if (-not $RuleName) {  # Only check for deletions when syncing all rules
        Write-Host "`n🔍 Checking for deleted rules..." -ForegroundColor Cyan
        $deletedRules = Find-DeletedRules -portalRules $rules -env $Environment
        if ($deletedRules.Count -gt 0) {
            Write-Host "📋 Found $($deletedRules.Count) deleted rule(s):" -ForegroundColor Yellow
            foreach ($deleted in $deletedRules) {
                Write-Host " - $($deleted.DisplayName) ($($deleted.Name))" -ForegroundColor Red
                $allChanges += [PSCustomObject]@{
                    Rule    = $deleted.DisplayName
                    Name    = $deleted.Name
                    Changes = @("rule: deleted from portal")
                }
            }
        }
    }
    
    foreach ($rule in $rules) {
        $cleanRuleName = Get-RuleNameFromDisplay -DisplayName $rule.displayName
        
        Write-Host "`n🔄 Processing rule: $($rule.displayName)" -ForegroundColor Cyan
        
        # Extract entity mappings
        $entities = @{}
        if ($rule.entityMappings) {
            foreach ($mapping in $rule.entityMappings) {
                $etype = ("" + $mapping.entityType)
                $col = if ($mapping.fieldMappings -and $mapping.fieldMappings.Count -gt 0) { $mapping.fieldMappings[0].columnName } else { '' }
                switch ($etype) {
                    "IP"      { $entities.ipAddress = $col }
                    "Account" { $entities.accountFullName = $col }
                    "Host"    { $entities.hostName = $col }
                    default    { $entities[$etype] = $col }
                }
            }
        }

        # If entities/grouping look incomplete from list API, fetch full rule details
        $needDetail = ($entities.Keys.Count -eq 0) -or ([string]::IsNullOrWhiteSpace("" + $rule.groupingEnabled)) -or ([string]::IsNullOrWhiteSpace("" + $rule.groupingMethod))
        if ($needDetail) {
            try {
                # Fallback to REST for broad compatibility across CLI versions
                $subId = Get-SubscriptionId
                $api = "2023-02-01-preview"
                $uri = "/subscriptions/$subId/resourceGroups/$ResourceGroup/providers/Microsoft.OperationalInsights/workspaces/$WorkspaceName/providers/Microsoft.SecurityInsights/alertRules/$($rule.name)?api-version=$api"
                $detail = az rest --method get --url $uri --output json | ConvertFrom-Json
                if ($detail) {
                    # Some payloads nest under properties
                    $props = if ($detail.properties) { $detail.properties } else { $detail }
                    
                    # Update missing fields from detailed response
                    if ($props.techniques -and $props.techniques.Count -gt 0) {
                        $rule.techniques = $props.techniques
                    }
                    if ($props.createIncident -ne $null) {
                        $rule.createIncident = $props.createIncident
                    }
                    
                    # Overwrite entities from detail if present
                    if ($props.entityMappings) {
                        $entities = @{}
                        foreach ($dm in $props.entityMappings) {
                            $etype = ("" + $dm.entityType)
                            $col = if ($dm.fieldMappings -and $dm.fieldMappings.Count -gt 0) { $dm.fieldMappings[0].columnName } else { '' }
                            switch ($etype) {
                                "IP"      { $entities.ipAddress = $col }
                                "Account" { $entities.accountFullName = $col }
                                "Host"    { $entities.hostName = $col }
                                default    { $entities[$etype] = $col }
                            }
                        }
                    }
                    # Map grouping configuration if present (Sentinel schema nests under incidentConfiguration)
                    $groupConf = $null
                    if ($props.incidentConfiguration -and $props.incidentConfiguration.groupingConfiguration) {
                        $groupConf = $props.incidentConfiguration.groupingConfiguration
                    } elseif ($props.groupingConfiguration) {
                        # fallback for older shapes
                        $groupConf = $props.groupingConfiguration
                    }
                    if ($groupConf) {
                        $ge = ("" + $groupConf.enabled)
                        $gm = ("" + $groupConf.matchingMethod)
                        $rule | Add-Member -NotePropertyName groupingEnabled -NotePropertyValue $ge -Force
                        $rule | Add-Member -NotePropertyName groupingMethod  -NotePropertyValue $gm -Force
                    }
                }
            } catch {
                Write-Host "   Note: Failed to fetch rule details for entities/grouping" -ForegroundColor DarkGray
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
        
        # Canonical comparison of the whole rule (metadata + KQL)
        $portalCanon = Get-CanonicalFromPortal -rule $rule -entities $entities -env $Environment
        $repoCanon   = Get-CanonicalFromRepo -displayName $rule.displayName -cleanName $cleanRuleName -env $Environment
        

        # Ensure non-null PSCustomObject for comparison
        if ($null -eq $repoCanon) { $repoCanon = [pscustomobject]@{ } }
        if ($null -eq $portalCanon) { $portalCanon = [pscustomobject]@{ } }
        $ruleChanges = Compare-Canon -repo $repoCanon -portal $portalCanon
        $changesDetected = ($ruleChanges.Count -gt 0)
        
        $kqlChanged = ($ruleChanges | Where-Object { $_ -match '^kql:' }).Count -gt 0
        $metadataChanged = ($ruleChanges | Where-Object { $_ -notmatch '^kql:' }).Count -gt 0
        
        # Only update if changes are detected or ForceSync is enabled
        if ($changesDetected -or $ForceSync) {
            if ($ForceSync) {
                Write-Host "   🔄 Force sync enabled - updating files" -ForegroundColor Cyan
            }
            
            # Update KQL only if changed or force
            if ($kqlChanged -or $ForceSync) {
                Update-KqlFile -RuleName $cleanRuleName -Query $rule.query
            } else {
                Write-Host "   ✅ KQL unchanged - skipping update" -ForegroundColor Green
            }
            
            # Update Bicep only if metadata changed or force
            if ($metadataChanged -or $ForceSync) {
                Update-BicepConfig -RuleName $cleanRuleName -PortalCanon $portalCanon -OriginalDisplayName $rule.displayName
            } else {
                Write-Host "   ✅ Metadata unchanged - skipping Bicep update" -ForegroundColor Green
            }
            
            $updatedCount++
            if ($ruleChanges.Count -gt 0) {
                $allChanges += [PSCustomObject]@{
                    Rule    = $rule.displayName
                    Name    = $cleanRuleName
                    Changes = $ruleChanges
                }
            }
        } else {
            Write-Host "   ✅ No changes detected - skipping" -ForegroundColor Green
        }
    }
    
    # Process deleted rules
    if ($deletedRules.Count -gt 0 -and -not $DryRun) {
        Write-Host "`n🗑️  Processing deleted rules..." -ForegroundColor Red
        foreach ($deleted in $deletedRules) {
            # Remove from both dev and prod Bicep files
            Remove-RuleFromBicep -ruleName $deleted.Name -displayName $deleted.DisplayName -env "dev"
            Remove-RuleFromBicep -ruleName $deleted.Name -displayName $deleted.DisplayName -env "prod"
            Remove-UnusedKqlFile -ruleName $deleted.Name
            $updatedCount++
        }
    }

    # Sync KQL files between dev and prod to keep environments in sync
    if (-not $DryRun -and ($updatedCount -gt 0 -or $deletedRules.Count -gt 0)) {
        Write-Host "`n🔄 Syncing KQL files between dev and prod environments..." -ForegroundColor Cyan

        $devKqlPath = "organizations/$Organization/kql/dev"
        $prodKqlPath = "organizations/$Organization/kql/prod"

        # Create prod directory if it doesn't exist
        if (-not (Test-Path $prodKqlPath)) {
            New-Item -ItemType Directory -Path $prodKqlPath -Force | Out-Null
            Write-Host "  📁 Created prod KQL directory: $prodKqlPath" -ForegroundColor Blue
        }

        # Copy all KQL files from dev to prod
        $devKqlFiles = Get-ChildItem "$devKqlPath/*.kql" -ErrorAction SilentlyContinue
        if ($devKqlFiles.Count -gt 0) {
            foreach ($kqlFile in $devKqlFiles) {
                $prodFilePath = "$prodKqlPath/$($kqlFile.Name)"
                Copy-Item -Path $kqlFile.FullName -Destination $prodFilePath -Force
                Write-Host "  📋 Copied $($kqlFile.Name) to prod environment" -ForegroundColor Blue
            }
        }

        # Clean up any orphaned KQL files in prod that don't exist in dev
        $prodKqlFiles = Get-ChildItem "$prodKqlPath/*.kql" -ErrorAction SilentlyContinue
        foreach ($prodFile in $prodKqlFiles) {
            $devFilePath = "$devKqlPath/$($prodFile.Name)"
            if (-not (Test-Path $devFilePath)) {
                Remove-Item $prodFile.FullName -Force
                Write-Host "  🗑️  Removed orphaned KQL file from prod: $($prodFile.Name)" -ForegroundColor Yellow
            }
        }
    }

    if ($allChanges.Count -gt 0) {
        Write-Host "`n📝 Detected changes:" -ForegroundColor Cyan
        foreach ($c in $allChanges) {
            Write-Host " - $($c.Rule)" -ForegroundColor White
            foreach ($item in $c.Changes) {
                Write-Host "    • $item" -ForegroundColor Gray
            }
        }
    } else {
        Write-Host "`n✅ No changes detected" -ForegroundColor Green
    }
    
    if ($DryRun) {
        Write-Host "`n💡 To apply these changes, run without -DryRun flag" -ForegroundColor Cyan
    }
    
}
catch {
    Write-Host "❌ Error during sync: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
