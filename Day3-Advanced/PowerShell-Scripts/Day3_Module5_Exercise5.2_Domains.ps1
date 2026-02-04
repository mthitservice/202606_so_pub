# =============================================================================
# Day 3 - Module 5 - Exercise 5.2: Setting Up Domains
# =============================================================================
# Fabric Domains provide logical grouping for workspaces and governance

# Connect to Power BI
Connect-PowerBIServiceAccount

Write-Host "=== Fabric Domain Configuration ===" -ForegroundColor Cyan

# -----------------------------------------------------------------------------
# Domain Concepts
# -----------------------------------------------------------------------------
Write-Host @"

=== What are Fabric Domains? ===

Domains are logical containers for workspaces that enable:
- Delegated administration (domain admins manage their domains)
- Data mesh patterns (decentralized ownership)
- Organizational boundaries
- Domain-specific governance policies

Domain Hierarchy:
Tenant
├── Domain: Finance
│   ├── Workspace: Finance-Reports
│   ├── Workspace: Finance-Dev
│   └── Workspace: Finance-Staging
├── Domain: Sales
│   ├── Workspace: Sales-Analytics
│   └── Workspace: Sales-Dashboards
└── Domain: HR
    └── Workspace: HR-People-Analytics

"@ -ForegroundColor Yellow

# -----------------------------------------------------------------------------
# List Existing Domains (Admin API)
# -----------------------------------------------------------------------------
Write-Host "=== Listing Existing Domains ===" -ForegroundColor Cyan

$headers = @{
    "Authorization" = "Bearer $(Get-PowerBIAccessToken -AsString)"
}

try {
    $domainsUrl = "https://api.fabric.microsoft.com/v1/admin/domains"
    $domains = Invoke-RestMethod -Method Get -Uri $domainsUrl -Headers $headers
    
    if ($domains.value) {
        Write-Host "Found $($domains.value.Count) domain(s):" -ForegroundColor Green
        $domains.value | ForEach-Object {
            Write-Host "`n  Domain: $($_.displayName)" -ForegroundColor Cyan
            Write-Host "    ID: $($_.id)"
            Write-Host "    Description: $($_.description)"
        }
    } else {
        Write-Host "No domains configured yet" -ForegroundColor Yellow
    }
} catch {
    Write-Host "Could not list domains: $($_.Exception.Message)" -ForegroundColor Yellow
    Write-Host "Note: Domains API requires admin permissions" -ForegroundColor Yellow
}

# -----------------------------------------------------------------------------
# Create a New Domain (Admin API)
# -----------------------------------------------------------------------------
function New-FabricDomain {
    param(
        [Parameter(Mandatory=$true)][string]$DisplayName,
        [string]$Description = ""
    )
    
    $body = @{
        displayName = $DisplayName
        description = $Description
    } | ConvertTo-Json
    
    $headers = @{
        "Authorization" = "Bearer $(Get-PowerBIAccessToken -AsString)"
        "Content-Type" = "application/json"
    }
    
    try {
        $createUrl = "https://api.fabric.microsoft.com/v1/admin/domains"
        $result = Invoke-RestMethod -Method Post -Uri $createUrl -Headers $headers -Body $body
        
        Write-Host "Created domain: $DisplayName" -ForegroundColor Green
        Write-Host "Domain ID: $($result.id)"
        return $result
    } catch {
        Write-Host "Failed to create domain: $($_.Exception.Message)" -ForegroundColor Red
        return $null
    }
}

# Example usage (uncomment to create):
# New-FabricDomain -DisplayName "Finance" -Description "Finance department data and reports"
# New-FabricDomain -DisplayName "Sales" -Description "Sales analytics and dashboards"
# New-FabricDomain -DisplayName "HR" -Description "HR and people analytics"

# -----------------------------------------------------------------------------
# Assign Workspaces to Domain
# -----------------------------------------------------------------------------
function Add-WorkspaceToDomain {
    param(
        [Parameter(Mandatory=$true)][string]$DomainId,
        [Parameter(Mandatory=$true)][string[]]$WorkspaceIds
    )
    
    $body = @{
        workspacesIds = $WorkspaceIds
    } | ConvertTo-Json
    
    $headers = @{
        "Authorization" = "Bearer $(Get-PowerBIAccessToken -AsString)"
        "Content-Type" = "application/json"
    }
    
    try {
        $assignUrl = "https://api.fabric.microsoft.com/v1/admin/domains/$DomainId/assignWorkspaces"
        Invoke-RestMethod -Method Post -Uri $assignUrl -Headers $headers -Body $body
        
        Write-Host "Assigned $($WorkspaceIds.Count) workspace(s) to domain" -ForegroundColor Green
    } catch {
        Write-Host "Failed to assign workspaces: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Example usage (uncomment to assign):
# Add-WorkspaceToDomain -DomainId "domain-guid" -WorkspaceIds @("workspace-guid-1", "workspace-guid-2")

# -----------------------------------------------------------------------------
# Assign Domain Admin
# -----------------------------------------------------------------------------
function Add-DomainAdmin {
    param(
        [Parameter(Mandatory=$true)][string]$DomainId,
        [Parameter(Mandatory=$true)][string]$AdminGroupId
    )
    
    $body = @{
        principalId = $AdminGroupId
        principalType = "Group"
    } | ConvertTo-Json
    
    $headers = @{
        "Authorization" = "Bearer $(Get-PowerBIAccessToken -AsString)"
        "Content-Type" = "application/json"
    }
    
    try {
        $adminUrl = "https://api.fabric.microsoft.com/v1/admin/domains/$DomainId/roleAssignments"
        Invoke-RestMethod -Method Post -Uri $adminUrl -Headers $headers -Body $body
        
        Write-Host "Assigned domain admin" -ForegroundColor Green
    } catch {
        Write-Host "Failed to assign admin: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# -----------------------------------------------------------------------------
# Domain Setup Checklist
# -----------------------------------------------------------------------------
Write-Host "`n=== Domain Setup Checklist ===" -ForegroundColor Yellow

Write-Host @"

Before Creating Domains:
[ ] Define organizational structure (departments, projects, etc.)
[ ] Identify domain owners/admins
[ ] Create Entra ID groups for domain admins
[ ] Plan workspace-to-domain mappings

Creating a Domain:
1. Admin Portal > Domains > Create
2. Enter name and description
3. Assign domain admins (security group)
4. Move workspaces to domain

Domain Governance Options:
[ ] Set default sensitivity labels for domain
[ ] Configure domain-specific endorsement settings
[ ] Define data quality requirements
[ ] Establish domain documentation standards

Example Domain Structure:

Domain: Finance
├── Admin Group: SG-Fabric-Finance-Admins
├── Workspaces:
│   ├── Finance-Production (production reports)
│   ├── Finance-Development (dev/test)
│   └── Finance-Archive (historical)
└── Settings:
    ├── Default Label: Confidential
    └── Certification Required: Yes
"@
