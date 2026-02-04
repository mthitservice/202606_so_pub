# =============================================================================
# Day 2 - Module 5 - Exercise 5.1: Workspace Inventory Script
# =============================================================================
# Creates a comprehensive workspace inventory with all details

# Connect to Power BI
Connect-PowerBIServiceAccount

Write-Host "=== Creating Workspace Inventory ===" -ForegroundColor Cyan

# Get all workspaces with full details
$workspaces = Get-PowerBIWorkspace -Scope Organization -All -Include All

Write-Host "Retrieved $($workspaces.Count) workspaces" -ForegroundColor Green

# Build comprehensive inventory
$inventory = foreach ($ws in $workspaces) {
    
    # Count items safely
    $reportCount = if ($ws.Reports) { @($ws.Reports).Count } else { 0 }
    $datasetCount = if ($ws.Datasets) { @($ws.Datasets).Count } else { 0 }
    $dataflowCount = if ($ws.Dataflows) { @($ws.Dataflows).Count } else { 0 }
    $dashboardCount = if ($ws.Dashboards) { @($ws.Dashboards).Count } else { 0 }
    $userCount = if ($ws.Users) { @($ws.Users).Count } else { 0 }
    
    [PSCustomObject]@{
        Name                   = $ws.Name
        Id                     = $ws.Id
        Type                   = $ws.Type
        State                  = $ws.State
        IsOnDedicatedCapacity  = $ws.IsOnDedicatedCapacity
        CapacityId             = $ws.CapacityId
        ReportCount            = $reportCount
        DatasetCount           = $datasetCount
        DataflowCount          = $dataflowCount
        DashboardCount         = $dashboardCount
        UserCount              = $userCount
        TotalItems             = $reportCount + $datasetCount + $dataflowCount + $dashboardCount
    }
}

# Export results
$outputFile = "CompleteWorkspaceInventory.csv"
$inventory | Export-Csv -Path $outputFile -NoTypeInformation -Encoding UTF8

Write-Host "Exported to: $outputFile" -ForegroundColor Green

# Display summary statistics
Write-Host "`n=== Workspace Summary ===" -ForegroundColor Cyan
Write-Host "Total Workspaces: $($workspaces.Count)"
Write-Host "Personal Workspaces: $(($workspaces | Where-Object {$_.Type -eq 'PersonalGroup'}).Count)"
Write-Host "Group Workspaces: $(($workspaces | Where-Object {$_.Type -eq 'Workspace'}).Count)"
Write-Host "On Premium Capacity: $(($workspaces | Where-Object {$_.IsOnDedicatedCapacity}).Count)"

Write-Host "`n=== Workspaces by Type ===" -ForegroundColor Yellow
$inventory | Group-Object Type | Select-Object Name, Count | Format-Table -AutoSize

Write-Host "=== Workspaces by State ===" -ForegroundColor Yellow
$inventory | Group-Object State | Select-Object Name, Count | Format-Table -AutoSize

Write-Host "=== Top 10 Largest Workspaces ===" -ForegroundColor Yellow
$inventory | 
    Sort-Object TotalItems -Descending | 
    Select-Object -First 10 Name, ReportCount, DatasetCount, TotalItems | 
    Format-Table -AutoSize

Write-Host "=== Empty Workspaces ===" -ForegroundColor Yellow
$emptyWorkspaces = $inventory | Where-Object { $_.TotalItems -eq 0 }
Write-Host "Found $($emptyWorkspaces.Count) empty workspaces"
if ($emptyWorkspaces.Count -gt 0 -and $emptyWorkspaces.Count -le 20) {
    $emptyWorkspaces | Select-Object Name, Type, State | Format-Table -AutoSize
}
