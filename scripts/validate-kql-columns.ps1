# KQL Column Validation Script
# Validates that columns referenced in entity mappings and custom details are actually projected in the KQL query

param(
    [string]$KqlFile,
    [string]$EntityMappings,
    [string]$CustomDetails
)

Write-Host "Validating KQL columns for: $KqlFile" -ForegroundColor Yellow

# Read the KQL file
if (-not (Test-Path $KqlFile)) {
    Write-Error "KQL file not found: $KqlFile"
    exit 1
}

$kqlContent = Get-Content $KqlFile -Raw
Write-Host "KQL Query:" -ForegroundColor Cyan
Write-Host $kqlContent -ForegroundColor Gray

# Extract projected columns from KQL
# Look for 'project' statements and extract column names
$projectMatch = [regex]::Match($kqlContent, 'project\s+(.+?)(?:\s*\|\s*|$)')
if ($projectMatch.Success) {
    $projectedColumns = $projectMatch.Groups[1].Value -split ',' | ForEach-Object { $_.Trim() }
    Write-Host "Projected columns: $($projectedColumns -join ', ')" -ForegroundColor Green
} else {
    Write-Host "No explicit 'project' statement found - all columns from previous steps are available" -ForegroundColor Yellow
    $projectedColumns = @()
}

# Validate entity mappings
if ($EntityMappings) {
    Write-Host "`nValidating entity mappings..." -ForegroundColor Yellow
    $entityMappingsObj = $EntityMappings | ConvertFrom-Json
    
    foreach ($entity in $entityMappingsObj) {
        foreach ($fieldMapping in $entity.fieldMappings) {
            $columnName = $fieldMapping.columnName
            if ($projectedColumns.Count -gt 0 -and $columnName -notin $projectedColumns) {
                Write-Warning "Entity mapping references column '$columnName' which is not explicitly projected in KQL"
            } else {
                Write-Host "✓ Entity mapping column '$columnName' is valid" -ForegroundColor Green
            }
        }
    }
}

# Validate custom details
if ($CustomDetails) {
    Write-Host "`nValidating custom details..." -ForegroundColor Yellow
    $customDetailsObj = $CustomDetails | ConvertFrom-Json
    
    foreach ($detail in $customDetailsObj.PSObject.Properties) {
        $columnName = $detail.Value
        if ($projectedColumns.Count -gt 0 -and $columnName -notin $projectedColumns) {
            Write-Warning "Custom detail references column '$columnName' which is not explicitly projected in KQL"
        } else {
            Write-Host "✓ Custom detail column '$columnName' is valid" -ForegroundColor Green
        }
    }
}

Write-Host "`nKQL validation completed" -ForegroundColor Green
