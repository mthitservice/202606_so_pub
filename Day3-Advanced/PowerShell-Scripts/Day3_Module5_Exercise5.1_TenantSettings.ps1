# =============================================================================
# Day 3 - Module 5 - Exercise 5.1: Configuring Tenant Settings
# =============================================================================
# This script documents and exports tenant settings configuration
# Note: Tenant settings are configured in the Admin Portal UI, but can be 
# audited and documented via API

# Connect to Power BI
Connect-PowerBIServiceAccount

Write-Host "=== Tenant Settings Configuration Guide ===" -ForegroundColor Cyan

# -----------------------------------------------------------------------------
# Recommended Tenant Settings Configuration
# -----------------------------------------------------------------------------
$recommendedSettings = @"

=== EXPORT AND SHARING SETTINGS ===

Setting: Export to Excel
  - Status: Enabled
  - Apply to: Specific security groups
  - Group: "SG-Fabric-DataExport-Allowed"
  - Rationale: Control who can export raw data

Setting: Export to CSV
  - Status: Enabled
  - Apply to: Specific security groups
  - Group: "SG-Fabric-DataExport-Allowed"
  - Rationale: Control who can export raw data

Setting: Export to PDF/PowerPoint
  - Status: Enabled
  - Apply to: Entire organization
  - Rationale: Formatted exports are less risky

Setting: Share to Teams
  - Status: Enabled
  - Apply to: Entire organization
  - Rationale: Encourages collaboration

Setting: External sharing
  - Status: Disabled
  - Apply to: None (or specific exception group)
  - Rationale: Prevent data leakage

=== DEVELOPER SETTINGS ===

Setting: Service principals can use Fabric APIs
  - Status: Enabled
  - Apply to: Specific security groups
  - Group: "SG-Fabric-ServicePrincipals"
  - Rationale: Control automation access

Setting: Service principals can access read-only admin APIs
  - Status: Enabled
  - Apply to: Specific security groups
  - Group: "SG-Fabric-ServicePrincipals"
  - Rationale: Allow governance reporting

Setting: Allow XMLA endpoints
  - Status: Enabled (Read/Write)
  - Apply to: Specific security groups
  - Group: "SG-Fabric-Advanced-Users"
  - Rationale: Allow advanced tooling

Setting: Users can try paid Fabric features
  - Status: Disabled
  - Rationale: Control trial usage, manage costs

=== CONTENT PACK SETTINGS ===

Setting: Publish content packs (all features)
  - Status: Disabled
  - Rationale: Deprecated feature

=== WORKSPACE SETTINGS ===

Setting: Create workspaces
  - Status: Enabled
  - Apply to: Specific security groups
  - Group: "SG-Fabric-Workspace-Creators"
  - Rationale: Control workspace sprawl

=== CUSTOM VISUAL SETTINGS ===

Setting: Allow custom visuals from marketplace
  - Status: Enabled
  - Apply to: Entire organization

Setting: Allow only certified custom visuals
  - Status: Enabled
  - Rationale: Security - only use vetted visuals

=== AUDIT AND USAGE SETTINGS ===

Setting: Usage metrics for content creators
  - Status: Enabled
  - Rationale: Let creators see report usage

Setting: Per-user data in usage metrics
  - Status: Disabled
  - Rationale: Privacy - aggregate only

"@

Write-Host $recommendedSettings

# -----------------------------------------------------------------------------
# Export Current Settings (Admin API)
# -----------------------------------------------------------------------------
Write-Host "`n=== Exporting Current Tenant Settings ===" -ForegroundColor Cyan

$headers = @{
    "Authorization" = "Bearer $(Get-PowerBIAccessToken -AsString)"
}

try {
    # Note: This requires admin permissions
    $settingsUrl = "https://api.powerbi.com/v1.0/myorg/admin/tenantSettings"
    $settings = Invoke-RestMethod -Method Get -Uri $settingsUrl -Headers $headers
    
    $settings.tenantSettings | ForEach-Object {
        [PSCustomObject]@{
            SettingName = $_.settingName
            Enabled = $_.enabled
            CanSpecifySecurityGroups = $_.canSpecifySecurityGroups
            EnabledSecurityGroups = ($_.enabledSecurityGroups.name -join ", ")
        }
    } | Export-Csv -Path "TenantSettings_Export.csv" -NoTypeInformation
    
    Write-Host "Tenant settings exported to: TenantSettings_Export.csv" -ForegroundColor Green
    
} catch {
    Write-Host "Could not export tenant settings: $($_.Exception.Message)" -ForegroundColor Yellow
    Write-Host "Note: Requires Fabric Administrator role" -ForegroundColor Yellow
}

# -----------------------------------------------------------------------------
# Security Group Creation Script
# -----------------------------------------------------------------------------
Write-Host "`n=== Required Security Groups ===" -ForegroundColor Yellow

$requiredGroups = @(
    @{ Name = "SG-Fabric-DataExport-Allowed"; Description = "Users allowed to export data" },
    @{ Name = "SG-Fabric-ServicePrincipals"; Description = "Service principals for API access" },
    @{ Name = "SG-Fabric-Advanced-Users"; Description = "Users with XMLA/advanced access" },
    @{ Name = "SG-Fabric-Workspace-Creators"; Description = "Users who can create workspaces" },
    @{ Name = "SG-Fabric-Admins"; Description = "Fabric tenant administrators" }
)

Write-Host "Create these groups in Entra ID before configuring tenant settings:`n"
$requiredGroups | ForEach-Object {
    Write-Host "  $($_.Name)" -ForegroundColor Cyan
    Write-Host "    $($_.Description)" -ForegroundColor Gray
}
