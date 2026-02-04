# =============================================================================
# Day 3 - Module 5 - Exercise 5.4: Implementing Sensitivity Labels
# =============================================================================
# Configure and apply Microsoft Purview sensitivity labels to Fabric content

# Connect to Power BI
Connect-PowerBIServiceAccount

Write-Host "=== Sensitivity Labels Configuration ===" -ForegroundColor Cyan

# -----------------------------------------------------------------------------
# Understanding Sensitivity Labels
# -----------------------------------------------------------------------------
Write-Host @"

=== Sensitivity Labels in Fabric ===

Sensitivity labels from Microsoft Purview protect data by:
- Applying encryption
- Adding visual markings (headers/footers)
- Controlling sharing and export
- Tracking data across the organization

Label Hierarchy (typical):
├── Public (no restrictions)
├── General (internal use)
├── Confidential
│   ├── All Employees
│   └── Specific People Only
└── Highly Confidential
    └── Specific People Only

Label Inheritance in Fabric:
Data Source → Dataset → Report → Dashboard → Export
     ↓           ↓         ↓          ↓          ↓
  [Label]    inherits  inherits  inherits   carries

"@ -ForegroundColor Yellow

# -----------------------------------------------------------------------------
# Check Sensitivity Label Configuration
# -----------------------------------------------------------------------------
Write-Host "`n=== Checking Label Configuration ===" -ForegroundColor Cyan

$headers = @{
    "Authorization" = "Bearer $(Get-PowerBIAccessToken -AsString)"
}

# Check if sensitivity labels are enabled for the tenant
try {
    # Get available labels
    $labelsUrl = "https://api.powerbi.com/v1.0/myorg/informationProtection/labels"
    $labels = Invoke-RestMethod -Method Get -Uri $labelsUrl -Headers $headers -ErrorAction SilentlyContinue
    
    if ($labels.value) {
        Write-Host "Available Sensitivity Labels:" -ForegroundColor Green
        $labels.value | ForEach-Object {
            Write-Host "  - $($_.name) (ID: $($_.id))" -ForegroundColor Cyan
        }
    }
} catch {
    Write-Host "Could not retrieve labels. Sensitivity labels may not be configured." -ForegroundColor Yellow
    Write-Host "Configure in Microsoft Purview compliance portal first." -ForegroundColor Yellow
}

# -----------------------------------------------------------------------------
# Get Label Status for Workspace Content
# -----------------------------------------------------------------------------
function Get-WorkspaceLabelStatus {
    param([string]$WorkspaceId)
    
    Write-Host "`nScanning workspace for sensitivity labels..." -ForegroundColor Cyan
    
    $results = @()
    
    # Check reports
    try {
        $reportsUrl = "https://api.powerbi.com/v1.0/myorg/groups/$WorkspaceId/reports"
        $reports = Invoke-RestMethod -Method Get -Uri $reportsUrl -Headers $headers
        
        $reports.value | ForEach-Object {
            $results += [PSCustomObject]@{
                Type = "Report"
                Name = $_.name
                SensitivityLabel = if ($_.sensitivityLabel) { $_.sensitivityLabel.labelId } else { "None" }
            }
        }
    } catch { }
    
    # Check datasets
    try {
        $datasetsUrl = "https://api.powerbi.com/v1.0/myorg/groups/$WorkspaceId/datasets"
        $datasets = Invoke-RestMethod -Method Get -Uri $datasetsUrl -Headers $headers
        
        $datasets.value | ForEach-Object {
            $results += [PSCustomObject]@{
                Type = "Dataset"
                Name = $_.name
                SensitivityLabel = if ($_.sensitivityLabel) { $_.sensitivityLabel.labelId } else { "None" }
            }
        }
    } catch { }
    
    if ($results) {
        $results | Format-Table -AutoSize
        
        # Summary
        $labeled = ($results | Where-Object { $_.SensitivityLabel -ne "None" }).Count
        $unlabeled = ($results | Where-Object { $_.SensitivityLabel -eq "None" }).Count
        
        Write-Host "Summary: $labeled labeled, $unlabeled unlabeled" -ForegroundColor Cyan
    }
    
    return $results
}

# Example usage (uncomment and provide workspace ID):
# Get-WorkspaceLabelStatus -WorkspaceId "your-workspace-id"

# -----------------------------------------------------------------------------
# Apply Sensitivity Label to Item
# -----------------------------------------------------------------------------
function Set-ItemSensitivityLabel {
    param(
        [Parameter(Mandatory=$true)][string]$WorkspaceId,
        [Parameter(Mandatory=$true)][string]$ItemId,
        [Parameter(Mandatory=$true)][ValidateSet("Report", "Dataset")]$ItemType,
        [Parameter(Mandatory=$true)][string]$LabelId
    )
    
    $body = @{
        sensitivityLabel = @{
            labelId = $LabelId
        }
    } | ConvertTo-Json -Depth 3
    
    $headers = @{
        "Authorization" = "Bearer $(Get-PowerBIAccessToken -AsString)"
        "Content-Type" = "application/json"
    }
    
    $itemTypePath = if ($ItemType -eq "Report") { "reports" } else { "datasets" }
    $url = "https://api.powerbi.com/v1.0/myorg/groups/$WorkspaceId/$itemTypePath/$ItemId"
    
    try {
        Invoke-RestMethod -Method Patch -Uri $url -Headers $headers -Body $body
        Write-Host "Applied sensitivity label to $ItemType" -ForegroundColor Green
    } catch {
        Write-Host "Failed to apply label: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Example usage (uncomment):
# Set-ItemSensitivityLabel -WorkspaceId "ws-id" -ItemId "item-id" -ItemType "Dataset" -LabelId "label-guid"

# -----------------------------------------------------------------------------
# Bulk Apply Labels to Unlabeled Content
# -----------------------------------------------------------------------------
function Set-DefaultLabelsInWorkspace {
    param(
        [Parameter(Mandatory=$true)][string]$WorkspaceId,
        [Parameter(Mandatory=$true)][string]$DefaultLabelId
    )
    
    Write-Host "Applying default label to unlabeled content..." -ForegroundColor Cyan
    
    $headers = @{
        "Authorization" = "Bearer $(Get-PowerBIAccessToken -AsString)"
        "Content-Type" = "application/json"
    }
    
    $appliedCount = 0
    
    # Label unlabeled reports
    $reportsUrl = "https://api.powerbi.com/v1.0/myorg/groups/$WorkspaceId/reports"
    $reports = Invoke-RestMethod -Method Get -Uri $reportsUrl -Headers $headers
    
    $reports.value | Where-Object { -not $_.sensitivityLabel } | ForEach-Object {
        try {
            $body = @{ sensitivityLabel = @{ labelId = $DefaultLabelId } } | ConvertTo-Json -Depth 3
            $url = "https://api.powerbi.com/v1.0/myorg/groups/$WorkspaceId/reports/$($_.id)"
            Invoke-RestMethod -Method Patch -Uri $url -Headers $headers -Body $body
            Write-Host "  Labeled report: $($_.name)" -ForegroundColor Green
            $appliedCount++
        } catch {
            Write-Host "  Failed: $($_.name)" -ForegroundColor Red
        }
    }
    
    # Label unlabeled datasets
    $datasetsUrl = "https://api.powerbi.com/v1.0/myorg/groups/$WorkspaceId/datasets"
    $datasets = Invoke-RestMethod -Method Get -Uri $datasetsUrl -Headers $headers
    
    $datasets.value | Where-Object { -not $_.sensitivityLabel } | ForEach-Object {
        try {
            $body = @{ sensitivityLabel = @{ labelId = $DefaultLabelId } } | ConvertTo-Json -Depth 3
            $url = "https://api.powerbi.com/v1.0/myorg/groups/$WorkspaceId/datasets/$($_.id)"
            Invoke-RestMethod -Method Patch -Uri $url -Headers $headers -Body $body
            Write-Host "  Labeled dataset: $($_.name)" -ForegroundColor Green
            $appliedCount++
        } catch {
            Write-Host "  Failed: $($_.name)" -ForegroundColor Red
        }
    }
    
    Write-Host "`nApplied labels to $appliedCount items" -ForegroundColor Cyan
}

# Example usage (uncomment):
# Set-DefaultLabelsInWorkspace -WorkspaceId "ws-id" -DefaultLabelId "general-label-guid"

# -----------------------------------------------------------------------------
# Sensitivity Label Setup Guide
# -----------------------------------------------------------------------------
Write-Host "`n=== Sensitivity Label Setup Guide ===" -ForegroundColor Yellow

Write-Host @"

Prerequisites:
1. Microsoft Purview license (E3/E5 or standalone)
2. Labels created in Microsoft Purview compliance portal
3. Labels published to users
4. Fabric tenant setting enabled: "Allow users to apply sensitivity labels"

Configuration Steps:

1. Create Labels in Purview:
   - compliance.microsoft.com > Information protection > Labels
   - Create label hierarchy (Public, Internal, Confidential, etc.)
   - Configure encryption settings (optional)
   - Configure content marking (optional)

2. Publish Labels:
   - Create label policy
   - Scope to all users or specific groups
   - Set default label (optional)
   - Require justification for downgrade (recommended)

3. Enable in Fabric Admin Portal:
   - Admin portal > Tenant settings > Information protection
   - Enable "Allow users to apply sensitivity labels"
   - Wait 24-48 hours for propagation

4. Apply Labels:
   - In Power BI Service: Item settings > Sensitivity label
   - Programmatically: Use API shown above
   - Automatically: Via Purview auto-labeling policies

Inheritance Rules:
- Dataset label flows to connected reports
- Report label flows to dashboard
- Label carried in exports
- Cannot downgrade without justification (if configured)
"@
