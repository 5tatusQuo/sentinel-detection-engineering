#!/usr/bin/env pwsh

<#
.SYNOPSIS
    Example deployment script using the organization configuration system

.DESCRIPTION
    This script demonstrates how to use the ConfigManager module to deploy
    to multiple organizations in a scalable way. It shows the pattern that
    should be used in GitHub Actions workflows.

.PARAMETER Environment
    The environment to deploy to (dev/prod)

.PARAMETER Organization
    Optional: Specific organization to deploy. If not provided, deploys to all enabled organizations.

.EXAMPLE
    .\deploy-with-config.ps1 -Environment "dev"
    
.EXAMPLE
    .\deploy-with-config.ps1 -Environment "prod" -Organization "org1"
#>

param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("dev", "prod")]
    [string]$Environment,
    
    [string]$Organization
)

# Import the configuration manager
. .\scripts\ConfigManager.ps1

Write-Host "🚀 Starting deployment using configuration system..." -ForegroundColor Cyan
Write-Host "Environment: $Environment" -ForegroundColor Yellow
if ($Organization) {
    Write-Host "Target Organization: $Organization" -ForegroundColor Yellow
} else {
    Write-Host "Target: All enabled organizations" -ForegroundColor Yellow
}
Write-Host ""

# Validate configuration
if (-not (Test-OrganizationConfig)) {
    Write-Host "❌ Configuration validation failed" -ForegroundColor Red
    exit 1
}

# Get organizations to deploy
if ($Organization) {
    # Deploy specific organization
    try {
        $org = Get-OrganizationByName -Name $Organization
        $orgsToDeploy = @($org)
        Write-Host "📋 Deploying to specific organization: $($org.displayName)" -ForegroundColor Green
    } catch {
        Write-Host "❌ Organization '$Organization' not found" -ForegroundColor Red
        exit 1
    }
} else {
    # Deploy all enabled organizations for this environment
    $orgsToDeploy = Get-EnabledOrganizations -Environment $Environment
    Write-Host "📋 Deploying to $($orgsToDeploy.Count) enabled organizations" -ForegroundColor Green
}

# Deploy to each organization
foreach ($org in $orgsToDeploy) {
    Write-Host "`n🏢 Processing organization: $($org.displayName) ($($org.name))" -ForegroundColor Cyan
    
    # Get environment configuration
    $envConfig = Get-OrganizationEnvironment -OrganizationName $org.name -Environment $Environment
    
    # Check if this environment is enabled for this organization
    if (-not $envConfig.enabled) {
        Write-Host "   ⚠️ Environment '$Environment' is disabled for $($org.name) - skipping" -ForegroundColor Yellow
        continue
    }
    
    # Get file paths
    $paths = Get-OrganizationPaths -OrganizationName $org.name -Environment $Environment
    
    Write-Host "   📁 Resource Group: $($envConfig.resourceGroup)" -ForegroundColor Gray
    Write-Host "   📁 Workspace: $($envConfig.workspaceName)" -ForegroundColor Gray
    Write-Host "   📁 Bicep File: $($paths.BicepPath)" -ForegroundColor Gray
    
    # Validate files exist
    if (-not (Test-Path $paths.BicepPath)) {
        Write-Host "   ❌ Bicep file not found: $($paths.BicepPath)" -ForegroundColor Red
        continue
    }
    
    if (-not (Test-Path $paths.KqlDirectory)) {
        Write-Host "   ❌ KQL directory not found: $($paths.KqlDirectory)" -ForegroundColor Red
        continue
    }
    
    # Simulate deployment (replace with actual deployment logic)
    Write-Host "   🔄 Deploying $($org.name) to $Environment environment..." -ForegroundColor Yellow
    
    # Example deployment command (commented out for demo)
    # az deployment group create `
    #     --resource-group $envConfig.resourceGroup `
    #     --template-file $paths.BicepPath `
    #     --verbose
    
    Write-Host "   ✅ Successfully deployed $($org.name) to $Environment" -ForegroundColor Green
}

Write-Host "`n🎉 Deployment completed!" -ForegroundColor Green
Write-Host "Deployed to $($orgsToDeploy.Count) organization(s)" -ForegroundColor Green
