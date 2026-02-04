# =============================================================================
# Day 3 - Module 5 - Exercise 5.3: Configuring Endorsement Process
# =============================================================================
# Set up content certification and promotion workflow

# Connect to Power BI
Connect-PowerBIServiceAccount

Write-Host "=== Endorsement Configuration ===" -ForegroundColor Cyan

# -----------------------------------------------------------------------------
# Understanding Endorsements
# -----------------------------------------------------------------------------
Write-Host @"

=== Endorsement Levels ===

1. NONE (default)
   - No badge
   - New content starts here

2. PROMOTED (yellow star)
   - Set by content owner
   - "I recommend this content"
   - No governance approval needed

3. CERTIFIED (green checkmark)
   - Set by designated certifiers only
   - "Governance-approved for production use"
   - Requires certification process

Benefits of Endorsements:
- Help users find trusted content
- Appear in search results with higher ranking
- Show endorsement badges in UI
- Enable governance workflows

"@ -ForegroundColor Yellow

# -----------------------------------------------------------------------------
# Get Current Endorsement Configuration
# -----------------------------------------------------------------------------
Write-Host "=== Current Endorsement Settings ===" -ForegroundColor Cyan

# Note: Endorsement settings are configured in Admin Portal
# This section shows how to check endorsement status via API

$headers = @{
    "Authorization" = "Bearer $(Get-PowerBIAccessToken -AsString)"
}

# -----------------------------------------------------------------------------
# Check Endorsed Content in a Workspace
# -----------------------------------------------------------------------------
function Get-EndorsedContent {
    param([string]$WorkspaceId)
    
    Write-Host "`nScanning workspace for endorsed content..." -ForegroundColor Cyan
    
    $endorsed = @()
    
    # Get reports
    try {
        $reportsUrl = "https://api.powerbi.com/v1.0/myorg/groups/$WorkspaceId/reports"
        $reports = Invoke-RestMethod -Method Get -Uri $reportsUrl -Headers $headers
        
        $reports.value | Where-Object { $_.endorsementDetails } | ForEach-Object {
            $endorsed += [PSCustomObject]@{
                Type = "Report"
                Name = $_.name
                Endorsement = $_.endorsementDetails.endorsement
                CertifiedBy = $_.endorsementDetails.certifiedBy
            }
        }
    } catch { }
    
    # Get datasets
    try {
        $datasetsUrl = "https://api.powerbi.com/v1.0/myorg/groups/$WorkspaceId/datasets"
        $datasets = Invoke-RestMethod -Method Get -Uri $datasetsUrl -Headers $headers
        
        $datasets.value | Where-Object { $_.endorsementDetails } | ForEach-Object {
            $endorsed += [PSCustomObject]@{
                Type = "Dataset"
                Name = $_.name
                Endorsement = $_.endorsementDetails.endorsement
                CertifiedBy = $_.endorsementDetails.certifiedBy
            }
        }
    } catch { }
    
    if ($endorsed) {
        Write-Host "Endorsed content found:" -ForegroundColor Green
        $endorsed | Format-Table -AutoSize
    } else {
        Write-Host "No endorsed content found in this workspace" -ForegroundColor Yellow
    }
    
    return $endorsed
}

# Example usage (uncomment and provide workspace ID):
# Get-EndorsedContent -WorkspaceId "your-workspace-id"

# -----------------------------------------------------------------------------
# Set Endorsement on Content
# -----------------------------------------------------------------------------
function Set-ContentEndorsement {
    param(
        [Parameter(Mandatory=$true)][string]$WorkspaceId,
        [Parameter(Mandatory=$true)][string]$ItemId,
        [Parameter(Mandatory=$true)][ValidateSet("Report", "Dataset")]$ItemType,
        [Parameter(Mandatory=$true)][ValidateSet("None", "Promoted", "Certified")]$Endorsement
    )
    
    $body = @{
        endorsementDetails = @{
            endorsement = $Endorsement
        }
    } | ConvertTo-Json -Depth 3
    
    $headers = @{
        "Authorization" = "Bearer $(Get-PowerBIAccessToken -AsString)"
        "Content-Type" = "application/json"
    }
    
    # Determine endpoint based on item type
    $itemTypePath = if ($ItemType -eq "Report") { "reports" } else { "datasets" }
    $url = "https://api.powerbi.com/v1.0/myorg/groups/$WorkspaceId/$itemTypePath/$ItemId"
    
    try {
        Invoke-RestMethod -Method Patch -Uri $url -Headers $headers -Body $body
        Write-Host "Set $Endorsement endorsement on $ItemType" -ForegroundColor Green
    } catch {
        Write-Host "Failed to set endorsement: $($_.Exception.Message)" -ForegroundColor Red
        if ($Endorsement -eq "Certified") {
            Write-Host "Note: Certification requires being a designated certifier" -ForegroundColor Yellow
        }
    }
}

# Example usage (uncomment):
# Set-ContentEndorsement -WorkspaceId "ws-id" -ItemId "item-id" -ItemType "Report" -Endorsement "Promoted"

# -----------------------------------------------------------------------------
# Certification Process Documentation
# -----------------------------------------------------------------------------
Write-Host "`n=== Certification Process Template ===" -ForegroundColor Yellow

$certificationProcess = @"

=== Content Certification Checklist ===

Before Requesting Certification:
[ ] Data source documented in description
[ ] Refresh schedule configured and working
[ ] RLS implemented (if applicable)
[ ] Sensitivity label applied
[ ] Owner/contact documented
[ ] Business glossary terms used
[ ] No hardcoded credentials or sensitive values
[ ] Performance tested (report loads < 10 seconds)

Certification Review Criteria:

1. DATA QUALITY
   [ ] Data sources are production-ready (not dev/test)
   [ ] Refresh history shows consistent success (30+ days)
   [ ] Data accuracy verified by business owner
   [ ] Edge cases handled appropriately

2. SECURITY
   [ ] RLS tested with multiple user accounts
   [ ] OLS applied to sensitive columns
   [ ] Appropriate sensitivity label assigned
   [ ] No over-sharing of permissions

3. DOCUMENTATION
   [ ] Report/dataset description complete
   [ ] Measure descriptions added
   [ ] Contact information current
   [ ] Known limitations documented

4. COMPLIANCE
   [ ] Follows organizational naming conventions
   [ ] Uses approved data sources
   [ ] Meets department-specific requirements
   [ ] Data retention policies considered

Certification Decision:
[ ] CERTIFIED - Meets all criteria
[ ] NEEDS WORK - See feedback below
[ ] REJECTED - Does not meet standards

Feedback:
_________________________________
_________________________________

Certified By: ___________________
Date: __________________________
Next Review: ____________________

"@

Write-Host $certificationProcess

# Export certification template
$certificationProcess | Out-File -FilePath "CertificationChecklist_Template.txt" -Encoding UTF8
Write-Host "`nCertification template saved to: CertificationChecklist_Template.txt" -ForegroundColor Green
