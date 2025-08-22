# Sync Vendor Rules Script
# This script handles syncing vendor rules for all organizations from production

param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('vendor', 'custom')]
    [string]$RuleType,

    [Parameter(Mandatory = $false)]
    [switch]$CreateBranch,

    [Parameter(Mandatory = $false)]
    [switch]$ForceSync
)

# Import ConfigManager
. "$PSScriptRoot/ConfigManager.ps1"

function Sync-VendorRulesForOrganizations {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RuleType,

        [Parameter(Mandatory = $false)]
        [switch]$CreateBranch,

        [Parameter(Mandatory = $false)]
        [switch]$ForceSync
    )

    Write-Host "🔄 Starting $RuleType rules sync for all organizations from production..." -ForegroundColor Green

    # Get enabled organizations for production
    $enabledOrgs = Get-EnabledOrganizations -Environment 'prod'

    if ($enabledOrgs.Count -eq 0) {
        Write-Host "⚠️ No enabled organizations found for production environment" -ForegroundColor Yellow
        return
    }

    Write-Host "📋 Found $($enabledOrgs.Count) enabled organization(s) for production:" -ForegroundColor Cyan
    foreach ($org in $enabledOrgs) {
        Write-Host "  - $($org.name) ($($org.displayName))" -ForegroundColor Gray
    }

    $processedCount = 0
    $successCount = 0
    $errorCount = 0

    foreach ($org in $enabledOrgs) {
        Write-Host "🔄 Processing $RuleType rules for $($org.name)..." -ForegroundColor Blue

        try {
            # Get environment-specific configuration
            $envConfig = Get-OrganizationEnvironment -OrganizationName $org.name -Environment 'prod'

            # Build the sync command arguments
            $syncArgs = @(
                "-ResourceGroup", $envConfig.resourceGroup,
                "-WorkspaceName", $envConfig.workspaceName,
                "-Environment", "prod",
                "-Organization", $org.name
            )

            # Add rule type specific arguments
            if ($RuleType -eq 'vendor') {
                $syncArgs += "-VendorRulesOnly"
            }

            if ($CreateBranch) {
                $syncArgs += "-CreateBranch"
            }

            if ($ForceSync) {
                $syncArgs += "-ForceSync"
            }

            Write-Host "  📋 Executing sync command..." -ForegroundColor Gray
            Write-Host "  Command: .\scripts\sync-sentinel-changes.ps1 $($syncArgs -join ' ')" -ForegroundColor DarkGray

            # Execute the sync script
            $syncCommand = "& `"$PSScriptRoot/sync-sentinel-changes.ps1`" $($syncArgs -join ' ')"
            Write-Host "  Running: $syncCommand" -ForegroundColor DarkGray
            $syncResult = Invoke-Expression $syncCommand

            if ($LASTEXITCODE -eq 0) {
                Write-Host "  ✅ $($org.name) $RuleType rules sync completed successfully" -ForegroundColor Green
                $successCount++
            } else {
                Write-Host "  ❌ $($org.name) $RuleType rules sync failed (exit code: $LASTEXITCODE)" -ForegroundColor Red
                $errorCount++
            }

            $processedCount++
        }
        catch {
            Write-Host "  ❌ Error processing $($org.name): $($_.Exception.Message)" -ForegroundColor Red
            $errorCount++
            $processedCount++
        }

        Write-Host "" # Add spacing between organizations
    }

    # Summary
    Write-Host "📊 $RuleType Rules Sync Summary:" -ForegroundColor Cyan
    Write-Host "  ✅ Successfully synced: $successCount organization(s)" -ForegroundColor Green
    Write-Host "  ❌ Failed: $errorCount organization(s)" -ForegroundColor Red
    Write-Host "  📈 Total processed: $processedCount organization(s)" -ForegroundColor Gray
}

# Main execution
try {
    Sync-VendorRulesForOrganizations -RuleType $RuleType -CreateBranch:$CreateBranch -ForceSync:$ForceSync
}
catch {
    Write-Host "❌ Vendor rules sync script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
