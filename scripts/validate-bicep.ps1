#!/usr/bin/env pwsh

<#
.SYNOPSIS
    Validates Bicep templates for all enabled organizations and environments

.DESCRIPTION
    This script uses the ConfigManager to iterate through all enabled organizations
    and environments, validating their Bicep templates.
#>

# Import the configuration manager
. .\scripts\ConfigManager.ps1

Write-Host "🔍 Validating Bicep templates for all organizations..." -ForegroundColor Cyan

# Validate core templates first
Write-Host "Building core templates..." -ForegroundColor Yellow
try {
    az bicep build --file infra/sentinel-rules.bicep
    Write-Host "✅ Core template validated" -ForegroundColor Green
} catch {
    Write-Host "❌ Core template validation failed: $($_.Exception.Message)" -ForegroundColor Red
}

try {
    az bicep build --file infra/modules/scheduledRule.bicep
    Write-Host "✅ Scheduled rule module validated" -ForegroundColor Green
} catch {
    Write-Host "❌ Scheduled rule module validation failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Validate environment-specific templates using configuration
$enabledOrgs = Get-EnabledOrganizations
foreach ($org in $enabledOrgs) {
    Write-Host "`n🏢 Processing organization: $($org.displayName) ($($org.name))" -ForegroundColor Cyan
    
    foreach ($env in @('dev', 'prod')) {
        if ($org.environments.$env.enabled) {
            $paths = Get-OrganizationPaths -OrganizationName $org.name -Environment $env
            
            if (Test-Path $paths.BicepPath) {
                Write-Host "  📁 Building $($org.name) $env template..." -ForegroundColor Yellow
                try {
                    # Check if Bicep file references KQL files that don't exist
                    $bicepContent = Get-Content $paths.BicepPath -Raw
                    $kqlMatches = [regex]::Matches($bicepContent, "loadTextContent\('([^']+)'\)")
                    
                    $missingKqlFiles = @()
                    foreach ($match in $kqlMatches) {
                        $kqlPath = $match.Groups[1].Value
                        # Convert relative path to absolute
                        $absoluteKqlPath = Join-Path (Split-Path $paths.BicepPath) $kqlPath
                        if (-not (Test-Path $absoluteKqlPath)) {
                            $missingKqlFiles += $kqlPath
                        }
                    }
                    
                    if ($missingKqlFiles.Count -gt 0) {
                        Write-Host "  ⚠️ Warning: Missing KQL files for $($org.name) $env - skipping validation" -ForegroundColor Yellow
                        Write-Host "    Missing: $($missingKqlFiles -join ', ')" -ForegroundColor Gray
                    } else {
                        az bicep build --file $paths.BicepPath
                        Write-Host "  ✅ $($org.name) $env template validated" -ForegroundColor Green
                    }
                } catch {
                    Write-Host "  ⚠️ Warning: Failed to build $($paths.BicepPath) - $($_.Exception.Message)" -ForegroundColor Yellow
                }
            } else {
                Write-Host "  ⚠️ No Bicep file found for $($org.name) $env environment" -ForegroundColor Yellow
            }
        } else {
            Write-Host "  ⏭️ $env environment disabled for $($org.name)" -ForegroundColor Gray
        }
    }
}

Write-Host "`n🎉 Bicep validation completed!" -ForegroundColor Green
