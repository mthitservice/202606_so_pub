# =============================================================================
# Day 2 - Module 3 - Exercise 3.4: Bulk Workspace Report
# =============================================================================
# This script generates a comprehensive report of all workspaces and contents

# Prerequisites: Run Exercise 3.2 first to get $global:FabricAccessToken

# Configuration
$outputPath = "WorkspaceReport_API.csv"
$delayMs = 500  # Delay between API calls to avoid throttling

# -----------------------------------------------------------------------------
# Ensure Token is Available
# -----------------------------------------------------------------------------
if (-not $global:FabricAccessToken) {
    Write-Host "ERROR: No access token found. Run Exercise 3.2 first." -ForegroundColor Red
    Write-Host "Alternatively, connect with Connect-PowerBIServiceAccount for user-based auth" -ForegroundColor Yellow
    exit
}

$headers = @{
    "Authorization" = "Bearer $($global:FabricAccessToken)"
    "Content-Type"  = "application/json"
}

# -----------------------------------------------------------------------------
# Step 1: Get All Workspaces (Admin API)
# -----------------------------------------------------------------------------
Write-Host "=== Fetching All Workspaces ===" -ForegroundColor Cyan

$workspacesUrl = "https://api.powerbi.com/v1.0/myorg/admin/groups?`$top=5000"

try {
    $workspaces = Invoke-RestMethod -Method Get -Uri $workspacesUrl -Headers $headers
    Write-Host "Found $($workspaces.value.Count) workspaces" -ForegroundColor Green
} catch {
    Write-Host "ERROR: Could not fetch workspaces" -ForegroundColor Red
    Write-Host "Note: Admin API requires Fabric Administrator role" -ForegroundColor Yellow
    Write-Host $_.Exception.Message
    exit
}

# -----------------------------------------------------------------------------
# Step 2: Get Details for Each Workspace
# -----------------------------------------------------------------------------
Write-Host "`n=== Fetching Workspace Details ===" -ForegroundColor Cyan

$report = @()
$counter = 0
$total = $workspaces.value.Count

foreach ($ws in $workspaces.value) {
    $counter++
    Write-Progress -Activity "Processing Workspaces" -Status "$counter of $total - $($ws.name)" -PercentComplete (($counter / $total) * 100)
    
    # Get expanded details including reports, datasets, users
    $detailUrl = "https://api.powerbi.com/v1.0/myorg/admin/groups/$($ws.id)?`$expand=reports,datasets,dataflows,users,dashboards"
    
    try {
        $detail = Invoke-RestMethod -Method Get -Uri $detailUrl -Headers $headers
        
        # Build report entry
        $entry = [PSCustomObject]@{
            WorkspaceName          = $detail.name
            WorkspaceId            = $detail.id
            Type                   = $detail.type
            State                  = $detail.state
            IsOnDedicatedCapacity  = $detail.isOnDedicatedCapacity
            CapacityId             = $detail.capacityId
            ReportCount            = if ($detail.reports) { $detail.reports.Count } else { 0 }
            DatasetCount           = if ($detail.datasets) { $detail.datasets.Count } else { 0 }
            DataflowCount          = if ($detail.dataflows) { $detail.dataflows.Count } else { 0 }
            DashboardCount         = if ($detail.dashboards) { $detail.dashboards.Count } else { 0 }
            UserCount              = if ($detail.users) { $detail.users.Count } else { 0 }
            AdminUsers             = if ($detail.users) { ($detail.users | Where-Object { $_.groupUserAccessRight -eq "Admin" }).Count } else { 0 }
            MemberUsers            = if ($detail.users) { ($detail.users | Where-Object { $_.groupUserAccessRight -eq "Member" }).Count } else { 0 }
            ContributorUsers       = if ($detail.users) { ($detail.users | Where-Object { $_.groupUserAccessRight -eq "Contributor" }).Count } else { 0 }
            ViewerUsers            = if ($detail.users) { ($detail.users | Where-Object { $_.groupUserAccessRight -eq "Viewer" }).Count } else { 0 }
        }
        
        $report += $entry
        
    } catch {
        Write-Warning "Could not get details for workspace: $($ws.name)"
        
        # Add partial entry
        $entry = [PSCustomObject]@{
            WorkspaceName          = $ws.name
            WorkspaceId            = $ws.id
            Type                   = $ws.type
            State                  = $ws.state
            IsOnDedicatedCapacity  = $ws.isOnDedicatedCapacity
            CapacityId             = $ws.capacityId
            ReportCount            = "Error"
            DatasetCount           = "Error"
            DataflowCount          = "Error"
            DashboardCount         = "Error"
            UserCount              = "Error"
            AdminUsers             = "Error"
            MemberUsers            = "Error"
            ContributorUsers       = "Error"
            ViewerUsers            = "Error"
        }
        $report += $entry
    }
    
    # Respect rate limits
    Start-Sleep -Milliseconds $delayMs
}

Write-Progress -Activity "Processing Workspaces" -Completed

# -----------------------------------------------------------------------------
# Step 3: Export Report
# -----------------------------------------------------------------------------
Write-Host "`n=== Exporting Report ===" -ForegroundColor Cyan

$report | Export-Csv -Path $outputPath -NoTypeInformation -Encoding UTF8
Write-Host "Report exported to: $outputPath" -ForegroundColor Green

# -----------------------------------------------------------------------------
# Step 4: Display Summary Statistics
# -----------------------------------------------------------------------------
Write-Host "`n=== Summary Statistics ===" -ForegroundColor Cyan

# Workspace Type Summary
Write-Host "`nWorkspaces by Type:" -ForegroundColor Yellow
$report | Group-Object Type | Select-Object Name, Count | Format-Table -AutoSize

# Capacity Summary
Write-Host "Capacity Assignment:" -ForegroundColor Yellow
$onCapacity = ($report | Where-Object { $_.IsOnDedicatedCapacity -eq $true }).Count
$notOnCapacity = ($report | Where-Object { $_.IsOnDedicatedCapacity -ne $true }).Count
Write-Host "  On Premium/Fabric Capacity: $onCapacity"
Write-Host "  Not on Capacity (Pro-only): $notOnCapacity"

# State Summary
Write-Host "`nWorkspaces by State:" -ForegroundColor Yellow
$report | Group-Object State | Select-Object Name, Count | Format-Table -AutoSize

# Content Summary
Write-Host "Total Content:" -ForegroundColor Yellow
$totalReports = ($report | Where-Object { $_.ReportCount -ne "Error" } | Measure-Object -Property ReportCount -Sum).Sum
$totalDatasets = ($report | Where-Object { $_.DatasetCount -ne "Error" } | Measure-Object -Property DatasetCount -Sum).Sum
$totalDataflows = ($report | Where-Object { $_.DataflowCount -ne "Error" } | Measure-Object -Property DataflowCount -Sum).Sum
Write-Host "  Total Reports:   $totalReports"
Write-Host "  Total Datasets:  $totalDatasets"
Write-Host "  Total Dataflows: $totalDataflows"

# Top 10 Largest Workspaces
Write-Host "`nTop 10 Workspaces by Content Count:" -ForegroundColor Yellow
$report | 
    Where-Object { $_.ReportCount -ne "Error" } |
    Select-Object WorkspaceName, ReportCount, DatasetCount, UserCount |
    Sort-Object ReportCount -Descending |
    Select-Object -First 10 |
    Format-Table -AutoSize

# Empty Workspaces
$emptyWorkspaces = $report | Where-Object { 
    $_.ReportCount -eq 0 -and $_.DatasetCount -eq 0 -and $_.DataflowCount -eq 0 
}
Write-Host "Empty Workspaces: $($emptyWorkspaces.Count)" -ForegroundColor Yellow
