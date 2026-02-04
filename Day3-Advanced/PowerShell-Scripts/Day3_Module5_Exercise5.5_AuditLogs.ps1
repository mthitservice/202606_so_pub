# =============================================================================
# Day 3 - Module 5 - Exercise 5.5: Audit Log Configuration
# =============================================================================
# Set up audit log monitoring and create compliance alerts

# Connect to Power BI
Connect-PowerBIServiceAccount

Write-Host "=== Audit Log Configuration ===" -ForegroundColor Cyan

# -----------------------------------------------------------------------------
# Understanding Power BI Audit Logs
# -----------------------------------------------------------------------------
Write-Host @"

=== Power BI Audit Logging ===

Audit logs capture all user activities in Power BI/Fabric:
- Report views and interactions
- Data exports
- Sharing actions
- Administrative changes
- Refresh operations
- Security changes

Retention:
- Default: 90 days (Microsoft 365)
- Extended: Up to 10 years with advanced compliance

Access Methods:
1. Power BI Activity Log API (30 days)
2. Microsoft 365 Audit Log (90 days)
3. Microsoft Purview (extended retention)

"@ -ForegroundColor Yellow

# -----------------------------------------------------------------------------
# Export Activity Logs (Last 7 Days)
# -----------------------------------------------------------------------------
Write-Host "`n=== Exporting Activity Logs ===" -ForegroundColor Cyan

$daysToExport = 7
$outputFile = "AuditLog_Export.csv"

$allActivities = @()

for ($i = 0; $i -lt $daysToExport; $i++) {
    $dayUtc = (Get-Date).ToUniversalTime().Date.AddDays(-$i)
    $start = $dayUtc.ToString("yyyy-MM-ddT00:00:00Z")
    $end = $dayUtc.ToString("yyyy-MM-ddT23:59:59Z")
    
    Write-Host "Fetching: $($dayUtc.ToString('yyyy-MM-dd'))" -NoNewline
    
    try {
        $json = Get-PowerBIActivityEvent -StartDateTime $start -EndDateTime $end -ResultType JsonString
        if ($json) {
            $events = $json | ConvertFrom-Json
            if ($events) {
                $allActivities += $events
                Write-Host " ($($events.Count) events)" -ForegroundColor Green
            } else {
                Write-Host " (0 events)" -ForegroundColor Gray
            }
        }
    } catch {
        Write-Host " (error)" -ForegroundColor Red
    }
}

if ($allActivities) {
    $allActivities | Export-Csv -Path $outputFile -NoTypeInformation -Encoding UTF8
    Write-Host "`nExported $($allActivities.Count) activities to: $outputFile" -ForegroundColor Green
}

# -----------------------------------------------------------------------------
# Analyze Key Activities
# -----------------------------------------------------------------------------
Write-Host "`n=== Activity Analysis ===" -ForegroundColor Cyan

if ($allActivities) {
    # Activity breakdown
    Write-Host "`nActivities by Type:" -ForegroundColor Yellow
    $allActivities | 
        Group-Object Operation | 
        Sort-Object Count -Descending | 
        Select-Object -First 15 Name, Count | 
        Format-Table -AutoSize
    
    # Export activities (high risk)
    Write-Host "Export Activities:" -ForegroundColor Yellow
    $exports = $allActivities | Where-Object { 
        $_.Operation -match "Export|Download" 
    }
    if ($exports) {
        Write-Host "Found $($exports.Count) export events"
        $exports | 
            Select-Object CreationTime, UserId, Operation, ReportName | 
            Select-Object -First 10 | 
            Format-Table -AutoSize
    }
    
    # Sharing activities
    Write-Host "`nSharing Activities:" -ForegroundColor Yellow
    $sharing = $allActivities | Where-Object { 
        $_.Operation -match "Share|AddLink|Permission" 
    }
    if ($sharing) {
        Write-Host "Found $($sharing.Count) sharing events"
        $sharing | 
            Select-Object CreationTime, UserId, Operation, ReportName | 
            Select-Object -First 10 | 
            Format-Table -AutoSize
    }
    
    # Admin activities
    Write-Host "`nAdmin Activities:" -ForegroundColor Yellow
    $admin = $allActivities | Where-Object { 
        $_.Operation -match "Admin|Setting|Tenant" 
    }
    if ($admin) {
        Write-Host "Found $($admin.Count) admin events"
        $admin | 
            Select-Object CreationTime, UserId, Operation | 
            Format-Table -AutoSize
    }
}

# -----------------------------------------------------------------------------
# Create Compliance Alert Report
# -----------------------------------------------------------------------------
Write-Host "`n=== Compliance Alert Configuration ===" -ForegroundColor Cyan

$alertConfig = @"

=== Recommended Alert Policies (Configure in Microsoft Purview) ===

1. Large Data Export Alert
   - Activity: ExportReport, DownloadReport
   - Threshold: > 10 exports per user per day
   - Action: Email to compliance team

2. External Sharing Alert
   - Activity: ShareReport (to external users)
   - Threshold: Any occurrence
   - Action: Email to data owner and compliance

3. Admin Setting Changes
   - Activity: UpdatedAdminFeatureSwitch, SetScheduledRefresh
   - Threshold: Any occurrence
   - Action: Email to IT admins

4. Failed Access Attempts
   - Activity: ViewReport (with failure)
   - Threshold: > 5 failures per user per hour
   - Action: Email to security team

5. Sensitive Data Access
   - Activity: ViewReport (with sensitivity label)
   - Threshold: Access to "Highly Confidential" content
   - Action: Log and review

"@

Write-Host $alertConfig

# -----------------------------------------------------------------------------
# Activities to Monitor (High Priority)
# -----------------------------------------------------------------------------
Write-Host "=== High Priority Activities to Monitor ===" -ForegroundColor Yellow

$priorityActivities = @(
    @{ Activity = "ExportReport"; Risk = "High"; Description = "User exported report data" },
    @{ Activity = "ExportTile"; Risk = "High"; Description = "User exported tile data" },
    @{ Activity = "DownloadReport"; Risk = "High"; Description = "User downloaded report" },
    @{ Activity = "ShareReport"; Risk = "Medium"; Description = "User shared a report" },
    @{ Activity = "CreateGroup"; Risk = "Low"; Description = "User created workspace" },
    @{ Activity = "DeleteReport"; Risk = "Medium"; Description = "User deleted report" },
    @{ Activity = "UpdatedAdminFeatureSwitch"; Risk = "High"; Description = "Admin changed tenant setting" },
    @{ Activity = "AddGroupMembers"; Risk = "Medium"; Description = "User added workspace members" },
    @{ Activity = "GenerateEmbedToken"; Risk = "Medium"; Description = "Embed token generated" },
    @{ Activity = "GetSnapshots"; Risk = "High"; Description = "User captured screenshot/snapshot" }
)

$priorityActivities | ForEach-Object { [PSCustomObject]$_ } | Format-Table -AutoSize

# -----------------------------------------------------------------------------
# Audit Log Retention Setup Guide
# -----------------------------------------------------------------------------
Write-Host "`n=== Audit Log Retention Setup ===" -ForegroundColor Yellow

Write-Host @"

For Extended Retention (beyond 90 days):

Option 1: Microsoft Purview Audit (Premium)
- Requires E5 or Compliance add-on
- Up to 10 years retention
- Advanced search capabilities

Option 2: Export to Your Own Storage
- Use PowerShell scripts (like this one) on schedule
- Store in Azure Blob, SQL Database, or Data Lake
- Build custom retention and analysis

Option 3: Azure Monitor / Log Analytics
- Stream audit logs to Log Analytics
- Custom retention policies
- Integration with Azure Sentinel

Recommended: Run daily export script and store in Fabric Lakehouse
for custom governance reporting and long-term retention.
"@

# -----------------------------------------------------------------------------
# Create Scheduled Export Script
# -----------------------------------------------------------------------------
Write-Host "`n=== Scheduled Export Script ===" -ForegroundColor Cyan

$scheduledScript = @'
# Save as: Export-DailyAuditLogs.ps1
# Schedule: Run daily at 2 AM via Task Scheduler or Azure Automation

param(
    [int]$DaysBack = 1,
    [string]$OutputPath = "C:\AuditLogs"
)

# Ensure output directory exists
if (-not (Test-Path $OutputPath)) {
    New-Item -ItemType Directory -Path $OutputPath -Force
}

# Connect (use Service Principal for automation)
Connect-PowerBIServiceAccount

# Export yesterday's logs
$dayUtc = (Get-Date).ToUniversalTime().Date.AddDays(-$DaysBack)
$start = $dayUtc.ToString("yyyy-MM-ddT00:00:00Z")
$end = $dayUtc.ToString("yyyy-MM-ddT23:59:59Z")

$fileName = "AuditLog_$($dayUtc.ToString('yyyy-MM-dd')).csv"
$filePath = Join-Path $OutputPath $fileName

$json = Get-PowerBIActivityEvent -StartDateTime $start -EndDateTime $end -ResultType JsonString
if ($json) {
    $events = $json | ConvertFrom-Json
    if ($events) {
        $events | Export-Csv -Path $filePath -NoTypeInformation -Encoding UTF8
        Write-Host "Exported $($events.Count) events to $filePath"
    }
}
'@

Write-Host $scheduledScript -ForegroundColor Gray
Write-Host "`nSave as scheduled task for daily audit log archival" -ForegroundColor Green
