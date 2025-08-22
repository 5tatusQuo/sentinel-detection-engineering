# Deploy Organizations Script
# This script handles the deployment of all enabled organizations to a specified environment

param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('dev', 'prod')]
    [string]$Environment
)

# Import ConfigManager
. "$PSScriptRoot/ConfigManager.ps1"

function Deploy-Organizations {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Environment
    )

    Write-Host "🚀 Starting deployment to $Environment environment..." -ForegroundColor Green

    # Get enabled organizations for the environment
    $enabledOrgs = Get-EnabledOrganizations -Environment $Environment

    if ($enabledOrgs.Count -eq 0) {
        Write-Host "⚠️ No enabled organizations found for $Environment environment" -ForegroundColor Yellow
        return
    }

    Write-Host "📋 Found $($enabledOrgs.Count) enabled organization(s) for $Environment environment:" -ForegroundColor Cyan
    foreach ($org in $enabledOrgs) {
        Write-Host "  - $($org.name) ($($org.displayName))" -ForegroundColor Gray
    }

    $deployedCount = 0
    $skippedCount = 0

    foreach ($org in $enabledOrgs) {
        Write-Host "🔄 Deploying $($org.name) to $Environment environment..." -ForegroundColor Blue

        try {
            # Get organization environment config
            $orgEnv = Get-OrganizationEnvironment -OrganizationName $org.name -Environment $Environment
            $paths = Get-OrganizationPaths -OrganizationName $org.name -Environment $Environment

            Write-Host "  📍 Resource Group: $($orgEnv.resourceGroup)" -ForegroundColor Gray
            Write-Host "  📄 Bicep Path: $($paths.BicepPath)" -ForegroundColor Gray

            # Check if Bicep file exists
            if (Test-Path $paths.BicepPath) {
                Write-Host "  📦 Deploying Bicep template..." -ForegroundColor Gray

                # Build the Bicep template first
                $bicepBuildResult = & az bicep build --file $paths.BicepPath 2>&1
                if ($LASTEXITCODE -ne 0) {
                    Write-Host "  ❌ Bicep build failed for $($org.name): $bicepBuildResult" -ForegroundColor Red
                    continue
                }

                # Deploy the template
                $deploymentResult = & az deployment group create `
                    --resource-group $orgEnv.resourceGroup `
                    --template-file $paths.BicepPath `
                    --verbose 2>&1

                if ($LASTEXITCODE -eq 0) {
                    Write-Host "  ✅ $($org.name) $Environment deployment completed successfully" -ForegroundColor Green
                    $deployedCount++
                } else {
                    Write-Host "  ❌ $($org.name) $Environment deployment failed: $deploymentResult" -ForegroundColor Red
                }
            } else {
                Write-Host "  ⚠️ No $Environment Bicep file found for $($org.name) - skipping" -ForegroundColor Yellow
                $skippedCount++
            }
        }
        catch {
            Write-Host "  ❌ Error deploying $($org.name): $($_.Exception.Message)" -ForegroundColor Red
        }

        Write-Host "" # Add spacing between organizations
    }

    # Summary
    Write-Host "📊 Deployment Summary for $Environment environment:" -ForegroundColor Cyan
    Write-Host "  ✅ Successfully deployed: $deployedCount organization(s)" -ForegroundColor Green
    Write-Host "  ⚠️ Skipped: $skippedCount organization(s)" -ForegroundColor Yellow
    Write-Host "  📈 Total processed: $($enabledOrgs.Count) organization(s)" -ForegroundColor Gray
}

# Main execution
try {
    Deploy-Organizations -Environment $Environment
}
catch {
    Write-Host "❌ Deployment script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
