# ConfigManager.ps1 - Organization Configuration Management Module

function Get-OrganizationConfig {
    <#
    .SYNOPSIS
        Loads and returns the organization configuration from config/organizations.json
    
    .DESCRIPTION
        Reads the JSON configuration file and returns a PowerShell object with all organization settings.
        This provides a centralized way to manage multiple organizations and their environments.
    
    .EXAMPLE
        $config = Get-OrganizationConfig
        $config.organizations | ForEach-Object { Write-Host $_.name }
    
    .EXAMPLE
        $config = Get-OrganizationConfig
        $org1 = $config.organizations | Where-Object { $_.name -eq "org1" }
        Write-Host "Org1 Dev RG: $($org1.environments.dev.resourceGroup)"
    #>
    
    param(
        [string]$ConfigPath = "config/organizations.json"
    )
    
    try {
        if (-not (Test-Path $ConfigPath)) {
            throw "Configuration file not found: $ConfigPath"
        }
        
        $configContent = Get-Content -Path $ConfigPath -Raw -Encoding UTF8
        $config = $configContent | ConvertFrom-Json
        
        # Validate required structure
        if (-not $config.organizations) {
            throw "Invalid configuration: missing 'organizations' array"
        }
        
        return $config
    }
    catch {
        Write-Error "Failed to load organization configuration: $($_.Exception.Message)"
        throw
    }
}

function Get-Organizations {
    <#
    .SYNOPSIS
        Returns all organizations from the configuration
    
    .DESCRIPTION
        Returns an array of all organizations defined in the configuration file.
    
    .EXAMPLE
        $orgs = Get-Organizations
        $orgs | ForEach-Object { Write-Host "Organization: $($_.name)" }
    #>
    
    param(
        [string]$ConfigPath = "config/organizations.json"
    )
    
    $config = Get-OrganizationConfig -ConfigPath $ConfigPath
    return $config.organizations
}

function Get-OrganizationByName {
    <#
    .SYNOPSIS
        Returns a specific organization by name
    
    .DESCRIPTION
        Finds and returns a specific organization configuration by its name.
    
    .PARAMETER Name
        The name of the organization to find
    
    .EXAMPLE
        $org1 = Get-OrganizationByName -Name "org1"
        Write-Host "Org1 Display Name: $($org1.displayName)"
    #>
    
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,
        
        [string]$ConfigPath = "config/organizations.json"
    )
    
    $config = Get-OrganizationConfig -ConfigPath $ConfigPath
    $org = $config.organizations | Where-Object { $_.name -eq $Name }
    
    if (-not $org) {
        throw "Organization '$Name' not found in configuration"
    }
    
    return $org
}

function Get-OrganizationEnvironment {
    <#
    .SYNOPSIS
        Returns environment configuration for a specific organization
    
    .DESCRIPTION
        Returns the environment configuration (dev/prod) for a specific organization.
    
    .PARAMETER OrganizationName
        The name of the organization
    
    .PARAMETER Environment
        The environment name (dev/prod)
    
    .EXAMPLE
        $env = Get-OrganizationEnvironment -OrganizationName "org1" -Environment "dev"
        Write-Host "Resource Group: $($env.resourceGroup)"
    #>
    
    param(
        [Parameter(Mandatory = $true)]
        [string]$OrganizationName,
        
        [Parameter(Mandatory = $true)]
        [ValidateSet("dev", "prod")]
        [string]$Environment,
        
        [string]$ConfigPath = "config/organizations.json"
    )
    
    $org = Get-OrganizationByName -Name $OrganizationName -ConfigPath $ConfigPath
    
    if (-not $org.environments.$Environment) {
        throw "Environment '$Environment' not found for organization '$OrganizationName'"
    }
    
    return $org.environments.$Environment
}

function Get-EnabledOrganizations {
    <#
    .SYNOPSIS
        Returns all organizations that have at least one enabled environment
    
    .DESCRIPTION
        Filters organizations to only return those that have at least one enabled environment.
    
    .PARAMETER Environment
        Optional: Filter to organizations with this specific environment enabled
    
    .EXAMPLE
        $enabledOrgs = Get-EnabledOrganizations
        $enabledOrgs | ForEach-Object { Write-Host "Enabled: $($_.name)" }
    
    .EXAMPLE
        $devOrgs = Get-EnabledOrganizations -Environment "dev"
        $devOrgs | ForEach-Object { Write-Host "Dev Enabled: $($_.name)" }
    #>
    
    param(
        [ValidateSet("dev", "prod")]
        [string]$Environment,
        
        [string]$ConfigPath = "config/organizations.json"
    )
    
    $config = Get-OrganizationConfig -ConfigPath $ConfigPath
    
    if ($Environment) {
        return $config.organizations | Where-Object { 
            $_.environments.$Environment.enabled -eq $true 
        }
    } else {
        return $config.organizations | Where-Object { 
            $_.environments.dev.enabled -eq $true -or $_.environments.prod.enabled -eq $true 
        }
    }
}

function Get-OrganizationPaths {
    <#
    .SYNOPSIS
        Returns file paths for a specific organization
    
    .DESCRIPTION
        Returns the standardized file paths for an organization's Bicep and KQL files.
    
    .PARAMETER OrganizationName
        The name of the organization
    
    .PARAMETER Environment
        The environment name (dev/prod)
    
    .EXAMPLE
        $paths = Get-OrganizationPaths -OrganizationName "org1" -Environment "dev"
        Write-Host "Bicep Path: $($paths.bicepPath)"
        Write-Host "KQL Directory: $($paths.kqlDirectory)"
    #>
    
    param(
        [Parameter(Mandatory = $true)]
        [string]$OrganizationName,
        
        [Parameter(Mandatory = $true)]
        [ValidateSet("dev", "prod")]
        [string]$Environment
    )
    
    $basePath = "organizations/$OrganizationName"
    
    return [PSCustomObject]@{
        OrganizationName = $OrganizationName
        Environment = $Environment
        BasePath = $basePath
        BicepPath = "$basePath/env/deploy-$Environment.bicep"
        KqlDirectory = "$basePath/kql/$Environment"
        EnvDirectory = "$basePath/env"
    }
}

function Test-OrganizationConfig {
    <#
    .SYNOPSIS
        Validates the organization configuration
    
    .DESCRIPTION
        Performs validation checks on the configuration file to ensure it's properly structured.
    
    .EXAMPLE
        $isValid = Test-OrganizationConfig
        if ($isValid) { Write-Host "Configuration is valid" }
    #>
    
    param(
        [string]$ConfigPath = "config/organizations.json"
    )
    
    try {
        $config = Get-OrganizationConfig -ConfigPath $ConfigPath
        
        # Check each organization
        foreach ($org in $config.organizations) {
            # Validate required fields
            if (-not $org.name) { throw "Organization missing 'name' field" }
            if (-not $org.environments) { throw "Organization '$($org.name)' missing 'environments' field" }
            
            # Validate environments
            foreach ($envName in @("dev", "prod")) {
                if ($org.environments.$envName) {
                    $env = $org.environments.$envName
                    if (-not $env.resourceGroup) { throw "Organization '$($org.name)' environment '$envName' missing 'resourceGroup'" }
                    if (-not $env.workspaceName) { throw "Organization '$($org.name)' environment '$envName' missing 'workspaceName'" }
                }
            }
        }
        
        Write-Host "✅ Configuration validation passed" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Error "❌ Configuration validation failed: $($_.Exception.Message)"
        return $false
    }
}

# Export functions for use in other scripts
Export-ModuleMember -Function @(
    'Get-OrganizationConfig',
    'Get-Organizations', 
    'Get-OrganizationByName',
    'Get-OrganizationEnvironment',
    'Get-EnabledOrganizations',
    'Get-OrganizationPaths',
    'Test-OrganizationConfig'
)
