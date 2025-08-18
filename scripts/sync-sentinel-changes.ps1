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
    [bool]$CreateBranch = $true,
    
    [Parameter(Mandatory = $false)]
    [bool]$ForceSync = $false,
    
    [Parameter(Mandatory = $false)]
    [bool]$VendorRulesOnly = $false,
    
    [Parameter(Mandatory = $false)]
    [switch]$DryRun
)

# Set error action preference
$ErrorActionPreference = "Stop"

Write-Host "🔄 Starting Sentinel to Repository Sync..." -ForegroundColor Cyan
Write-Host "Resource Group: $ResourceGroup" -ForegroundColor Yellow
Write-Host "Workspace: $WorkspaceName" -ForegroundColor Yellow
Write-Host "Environment: $Environment" -ForegroundColor Yellow
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
        [object]$PortalCanon
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
            switch ($PortalCanon.severity) {
                "Low" { "Medium" }
                "Medium" { "High" }
                "High" { "Critical" }
                "Critical" { "Critical" }
                default { "Medium" }
            }
        } else {
            $PortalCanon.severity
        }
        $envCreateIncident = if ($Environment -eq "prod") { "true" } else { $PortalCanon.createIncident }
        
        # Dynamically build entities block
        $entitiesBlock = ""
        if ($PortalCanon.entities -and $PortalCanon.entities.psobject.Properties.Count -gt 0) {
            $entitiesBlock = "    entities: {`n"
            foreach ($prop in $PortalCanon.entities.psobject.Properties) {
                $entitiesBlock += "      $($prop.Name): '$($prop.Value)'`n"
            }
            $entitiesBlock += "    }`n"
        } else {
            $entitiesBlock = "    entities: {}`n"
        }
        
        # Dynamically build grouping block
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
        
        # Build tactics and techniques
        $tacticsStr = if ($PortalCanon.tactics -and $PortalCanon.tactics.Count -gt 0) { $PortalCanon.tactics -join ', ' } else { '' }
        $techniquesStr = if ($PortalCanon.techniques -and $PortalCanon.techniques.Count -gt 0) { $PortalCanon.techniques -join ', ' } else { '' }
        
        $ruleObject = @"
  {
    name: '$RuleName'
    displayName: '$envPrefix [ORG] – $($PortalCanon.displayName)'
    kql: kql$RuleName
    severity: '$envSeverity'
    enabled: $($PortalCanon.enabled)
    frequency: '$($PortalCanon.frequency)'
    period: '$($PortalCanon.period)'
    tactics: [ $tacticsStr ]
    techniques: [ $techniquesStr ]
    createIncident: $envCreateIncident
$groupingBlock$entitiesBlock    customDetails: {
      // TODO: Sync customDetails if needed
    }
  }
"@
        
        # Helper to update content: replace if exists, else append to array
        function Update-Content {
            param([string]$content, [string]$ruleObj, [string]$rname)
            $escName = [regex]::Escape($rname)
            $pat = "(?s)\{\s*name:\s*'$escName'.*?\n\s*\}"
            if ($content -match $pat) {
                return $content -replace $pat, $ruleObj
            } else {
                # Append to the end of the rules array (assume array is var rules = [ ... ])
                $arrayPat = '(?s)var\s*rules\s*=\s*\[(.*?)\]'
                if ($content -match $arrayPat) {
                    $arrayContent = $matches[1].TrimEnd()
                    $newArray = "$arrayContent`n$ruleObj`n  ]"
                    return $content -replace $arrayPat, "var rules = [$newArray"
                }
            }
            return $content
        }
        
        # Update appropriate Bicep file based on environment
        if ($Environment -eq "prod") {
            $prodContent = Update-Content -content $prodContent -ruleObj $ruleObject -rname $RuleName
            $prodContent | Out-File -FilePath $prodBicepPath -Encoding UTF8
            Write-Host "✅ Updated PROD Bicep file for rule: $RuleName" -ForegroundColor Green
        } else {
            $devContent = Update-Content -content $devContent -ruleObj $ruleObject -rname $RuleName
            $devContent | Out-File -FilePath $devBicepPath -Encoding UTF8
            Write-Host "✅ Updated DEV Bicep file for rule: $RuleName" -ForegroundColor Green
        }
        
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
        $bicepPath = if ($env -eq 'prod') { 'env/deploy-prod.bicep' } else { 'env/deploy-dev.bicep' }
        if (-not (Test-Path $bicepPath)) { return $null }
        $content = Get-Content -Path $bicepPath -Raw

        # Try to find rule block by exact displayName first
        $escDisplay = [regex]::Escape($displayName)
        $block = $null
        $patDisplay = "(?s)\{\s*name:\s*'[^']*'\s*displayName:\s*'$escDisplay'.*?\n\s*\}"
        if ($content -match $patDisplay) {
            $block = $matches[0]
        } else {
            # Fallback: try by internal name (the repo 'name' field is not the cleanName; prefer displayName)
            $patName = "(?s)\{\s*name:\s*'" + [regex]::Escape($cleanName) + "'\b.*?\n\s*\}"
            if ($content -match $patName) { $block = $matches[0] }
        }
        if (-not $block) { return $null }
        function m($r) { if ($block -match $r) { return $matches[1] } else { return '' } }
        function parseList($r) {
            $raw = m $r
            if ([string]::IsNullOrWhiteSpace($raw)) { return @() }
            $items = @()
            foreach ($part in ($raw -split ',')) {
                $x = ($part -replace "'", '').Trim()
                if ($x) { $items += $x }
            }
            return (@($items) | Sort-Object -Unique)
        }
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
        # Entities block -> parse all key:'value' pairs (preserve any unknown keys)
        $entitiesMap = @{}
        $entBlock = $null
        if ($block -match "(?s)entities:\s*\{(.*?)\}") { $entBlock = $matches[1] }
        if ($entBlock) {
            $matchesFound = [regex]::Matches($entBlock, "(?m)^\s*([A-Za-z0-9_]+):\s*'([^']*)'")
            foreach ($mm in $matchesFound) {
                $entitiesMap[$mm.Groups[1].Value] = $mm.Groups[2].Value
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
            $varPat = "(?m)^\s*var\s+kql$kqlVar\s*=\s*loadTextContent\('\.\./kql/([^']+)'\)"
            if ($content -match $varPat) { $kqlFile = $matches[1] }
        }
        $kqlPath  = if ($kqlFile) { "kql/$kqlFile" } else { "kql/$cleanName.kql" }
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
                Update-BicepConfig -RuleName $cleanRuleName -PortalCanon $portalCanon
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
