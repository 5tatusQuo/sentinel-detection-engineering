#!/usr/bin/env pwsh

# Import the configuration manager
. .\scripts\ConfigManager.ps1

Write-Host "🧪 Testing Organization Configuration System" -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host ""

# Test 1: Load and validate configuration
Write-Host "1. Testing configuration loading..." -ForegroundColor Yellow
try {
    $config = Get-OrganizationConfig
    Write-Host "   ✅ Configuration loaded successfully" -ForegroundColor Green
    Write-Host "   📊 Found $($config.organizations.Count) organizations" -ForegroundColor Green
} catch {
    Write-Host "   ❌ Failed to load configuration: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Test 2: Validate configuration structure
Write-Host "`n2. Validating configuration structure..." -ForegroundColor Yellow
$isValid = Test-OrganizationConfig
if (-not $isValid) {
    Write-Host "   ❌ Configuration validation failed" -ForegroundColor Red
    exit 1
}

# Test 3: List all organizations
Write-Host "`n3. Listing all organizations..." -ForegroundColor Yellow
$orgs = Get-Organizations
foreach ($org in $orgs) {
    Write-Host "   📁 $($org.name) - $($org.displayName)" -ForegroundColor Green
    Write-Host "      Description: $($org.description)" -ForegroundColor Gray
    Write-Host "      Environments:" -ForegroundColor Gray
    foreach ($envName in @("dev", "prod")) {
        if ($org.environments.$envName) {
            $env = $org.environments.$envName
            $status = if ($env.enabled) { "✅" } else { "❌" }
            Write-Host "        $status $envName - RG: $($env.resourceGroup), WS: $($env.workspaceName)" -ForegroundColor Gray
        }
    }
}

# Test 4: Test organization-specific functions
Write-Host "`n4. Testing organization-specific functions..." -ForegroundColor Yellow
try {
    $org1 = Get-OrganizationByName -Name "org1"
    Write-Host "   ✅ Found org1: $($org1.displayName)" -ForegroundColor Green
    
    $org1Dev = Get-OrganizationEnvironment -OrganizationName "org1" -Environment "dev"
    Write-Host "   ✅ org1 dev environment: RG=$($org1Dev.resourceGroup), WS=$($org1Dev.workspaceName)" -ForegroundColor Green
    
    $paths = Get-OrganizationPaths -OrganizationName "org1" -Environment "dev"
    Write-Host "   ✅ org1 dev paths:" -ForegroundColor Green
    Write-Host "      Bicep: $($paths.BicepPath)" -ForegroundColor Gray
    Write-Host "      KQL Dir: $($paths.KqlDirectory)" -ForegroundColor Gray
} catch {
    Write-Host "   ❌ Organization-specific test failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Test 5: Test enabled organizations
Write-Host "`n5. Testing enabled organizations..." -ForegroundColor Yellow
$enabledOrgs = Get-EnabledOrganizations
Write-Host "   📊 Total enabled organizations: $($enabledOrgs.Count)" -ForegroundColor Green

$devEnabledOrgs = Get-EnabledOrganizations -Environment "dev"
Write-Host "   📊 Dev-enabled organizations: $($devEnabledOrgs.Count)" -ForegroundColor Green

$prodEnabledOrgs = Get-EnabledOrganizations -Environment "prod"
Write-Host "   📊 Prod-enabled organizations: $($prodEnabledOrgs.Count)" -ForegroundColor Green

Write-Host "`n🎉 Configuration system test completed!" -ForegroundColor Green
