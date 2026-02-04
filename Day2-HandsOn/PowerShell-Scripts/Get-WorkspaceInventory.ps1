# ============================================================
# Get-WorkspaceInventory.ps1
# Create a Complete Workspace Inventory Report
# ============================================================

# Login to Power BI Service
Connect-PowerBIServiceAccount

# Get all workspaces with full details (Organization scope requires admin)
$workspaces = Get-PowerBIWorkspace -Scope Organization -All -Include All |
    Where-Object { $_.Type -eq "Workspace" }

# Build inventory
$inventory = foreach ($ws in $workspaces) {
    [PSCustomObject]@{
        WorkspaceName  = $ws.Name
        WorkspaceId    = $ws.Id
        Type           = $ws.Type
        State          = $ws.State
        ReportCount    = @($ws.Reports).Count
        DatasetCount   = @($ws.Datasets).Count
        DataflowCount  = @($ws.Dataflows).Count
        DashboardCount = @($ws.Dashboards).Count
        CapacityId     = $ws.CapacityId
        IsOnPremium    = if ($ws.IsOnDedicatedCapacity) { "Yes" } else { "No" }
    }
}

# Export to CSV
$outFile = "WorkspaceInventory.csv"
$inventory | Export-Csv -Path $outFile -NoTypeInformation -Encoding UTF8

Write-Host "Exported $($inventory.Count) workspaces to $outFile" -ForegroundColor Green

# Summary statistics
Write-Host "`n=== Workspace Summary ===" -ForegroundColor Cyan
Write-Host "Total Workspaces: $($inventory.Count)"
Write-Host "Total Reports: $(($inventory | Measure-Object -Property ReportCount -Sum).Sum)"
Write-Host "Total Datasets: $(($inventory | Measure-Object -Property DatasetCount -Sum).Sum)"
Write-Host "On Premium Capacity: $(($inventory | Where-Object { $_.IsOnPremium -eq 'Yes' }).Count)"
