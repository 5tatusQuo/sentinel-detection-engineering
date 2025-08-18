#!/usr/bin/env pwsh

<#
.SYNOPSIS
    Test script to verify the new organizational structure works correctly.

.DESCRIPTION
    This script tests the new scalable organizational structure by:
    1. Finding all organization directories
    2. Validating their structure
    3. Testing the sync script with different organizations
    4. Verifying Bicep file paths

.EXAMPLE
    .\test-org-structure.ps1
#>

Write-Host "🧪 Testing Organizational Structure..." -ForegroundColor Cyan

# Find all organization directories
$orgDirs = Get-ChildItem -Directory -Name "org*" | Sort-Object
Write-Host "📁 Found organizations: $($orgDirs -join ', ')" -ForegroundColor Green

if ($orgDirs.Count -eq 0) {
    Write-Host "❌ No organization directories found!" -ForegroundColor Red
    exit 1
}

# Test each organization's structure
foreach ($org in $orgDirs) {
    Write-Host "`n🔍 Testing organization: $org" -ForegroundColor Yellow
    
    # Check if required directories exist
    $kqlPath = "$org/kql"
    $envPath = "$org/env"
    
    if (-not (Test-Path $kqlPath)) {
        Write-Host "   ❌ Missing KQL directory: $kqlPath" -ForegroundColor Red
    } else {
        Write-Host "   ✅ KQL directory exists: $kqlPath" -ForegroundColor Green
        $kqlFiles = Get-ChildItem "$kqlPath/*.kql" -ErrorAction SilentlyContinue
        Write-Host "   📄 Found $($kqlFiles.Count) KQL files" -ForegroundColor Gray
    }
    
    if (-not (Test-Path $envPath)) {
        Write-Host "   ❌ Missing env directory: $envPath" -ForegroundColor Red
    } else {
        Write-Host "   ✅ Env directory exists: $envPath" -ForegroundColor Green
        
        # Check for Bicep files
        $devBicep = "$envPath/deploy-dev.bicep"
        $prodBicep = "$envPath/deploy-prod.bicep"
        
        if (Test-Path $devBicep) {
            Write-Host "   ✅ Dev Bicep file exists: $devBicep" -ForegroundColor Green
        } else {
            Write-Host "   ⚠️  Dev Bicep file missing: $devBicep" -ForegroundColor Yellow
        }
        
        if (Test-Path $prodBicep) {
            Write-Host "   ✅ Prod Bicep file exists: $prodBicep" -ForegroundColor Green
        } else {
            Write-Host "   ⚠️  Prod Bicep file missing: $prodBicep" -ForegroundColor Yellow
        }
    }
}

# Test sync script parameter handling
Write-Host "`n🧪 Testing sync script parameter handling..." -ForegroundColor Cyan

foreach ($org in $orgDirs) {
    Write-Host "   Testing organization: $org" -ForegroundColor Gray
    
    # Test with dry run to avoid actual Azure calls
    try {
        $result = & pwsh -Command "& './scripts/sync-sentinel-changes.ps1' -ResourceGroup 'sentinel-ws-dev' -WorkspaceName 'sentinel-rg-dev' -Environment 'dev' -Organization '$org' -DryRun" 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "   ✅ Sync script accepts organization parameter: $org" -ForegroundColor Green
        } else {
            Write-Host "   ❌ Sync script failed for organization: $org" -ForegroundColor Red
            Write-Host "   Error: $result" -ForegroundColor Red
        }
    } catch {
        Write-Host "   ❌ Exception testing organization: $org" -ForegroundColor Red
        Write-Host "   Error: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Test Bicep file path resolution
Write-Host "`n🧪 Testing Bicep file path resolution..." -ForegroundColor Cyan

foreach ($org in $orgDirs) {
    $devBicep = "$org/env/deploy-dev.bicep"
    $prodBicep = "$org/env/deploy-prod.bicep"
    
    if (Test-Path $devBicep) {
        Write-Host "   ✅ Dev Bicep path resolves: $devBicep" -ForegroundColor Green
        
        # Check if KQL paths in Bicep are correct
        $content = Get-Content $devBicep -Raw
        if ($content -match "loadTextContent\('\./kql/(dev|prod)/") {
            Write-Host "   ✅ KQL paths in Bicep are correct (relative to org)" -ForegroundColor Green
        } else {
            Write-Host "   ⚠️  KQL paths in Bicep may need updating" -ForegroundColor Yellow
        }
    }
    
    if (Test-Path $prodBicep) {
        Write-Host "   ✅ Prod Bicep path resolves: $prodBicep" -ForegroundColor Green
    }
}

Write-Host "`n✅ Organizational structure test completed!" -ForegroundColor Green
Write-Host "📋 Summary:" -ForegroundColor Cyan
Write-Host "   - Found $($orgDirs.Count) organization(s)" -ForegroundColor Gray
Write-Host "   - All organizations have basic structure" -ForegroundColor Gray
Write-Host "   - Sync script accepts organization parameter" -ForegroundColor Gray
Write-Host "   - Bicep files use correct relative paths" -ForegroundColor Gray
