# =============================================================================
# Day 2 - Module 5 - Exercise 5.3: License Utilization Report
# =============================================================================
# Analyze Power BI license usage and identify inactive users

# -----------------------------------------------------------------------------
# Prerequisites
# -----------------------------------------------------------------------------
# Install-Module Microsoft.Graph -Scope CurrentUser -Force
# Install-Module MicrosoftPowerBIMgmt -Scope CurrentUser -Force

# Connect to Microsoft Graph for user/license data
Write-Host "=== Connecting to Microsoft Graph ===" -ForegroundColor Cyan
Connect-MgGraph -Scopes "User.Read.All", "Directory.Read.All"

# Connect to Power BI for activity data
Write-Host "Connecting to Power BI Service..." -ForegroundColor Cyan
Connect-PowerBIServiceAccount

# -----------------------------------------------------------------------------
# Step 1: Get Users with Power BI Licenses
# -----------------------------------------------------------------------------
Write-Host "`n=== Retrieving Licensed Users ===" -ForegroundColor Cyan

# Power BI license SKU IDs
$pbiSkus = @{
    "f8a1db68-be16-40ed-86d5-cb42ce701560" = "Power BI Pro"
    "c1d032e0-5619-4761-9b5c-7b33c8d9ffd0" = "Power BI Premium Per User"
    "3a6a908c-09c5-406a-8571-5d4d8a19e7ef" = "Power BI Free"
}

# Get all users with assigned licenses
$allUsers = Get-MgUser -All -Property DisplayName, UserPrincipalName, AssignedLicenses, AccountEnabled

# Filter to Power BI licensed users
$licensedUsers = @()
foreach ($user in $allUsers) {
    foreach ($license in $user.AssignedLicenses) {
        if ($pbiSkus.ContainsKey($license.SkuId)) {
            $licensedUsers += [PSCustomObject]@{
                DisplayName       = $user.DisplayName
                UserPrincipalName = $user.UserPrincipalName
                AccountEnabled    = $user.AccountEnabled
                LicenseType       = $pbiSkus[$license.SkuId]
                SkuId             = $license.SkuId
            }
        }
    }
}

Write-Host "Found $($licensedUsers.Count) users with Power BI licenses" -ForegroundColor Green

# License breakdown
Write-Host "`nLicense Distribution:" -ForegroundColor Yellow
$licensedUsers | Group-Object LicenseType | Select-Object Name, Count | Format-Table -AutoSize

# -----------------------------------------------------------------------------
# Step 2: Get Activity Data (Last 30 Days)
# -----------------------------------------------------------------------------
Write-Host "=== Retrieving Activity Data (Last 30 Days) ===" -ForegroundColor Cyan

$activityStart = (Get-Date).AddDays(-30).ToString("yyyy-MM-ddT00:00:00")
$activityEnd = (Get-Date).ToString("yyyy-MM-ddT23:59:59")

$allActivities = @()

# Fetch activity day by day (API limitation)
for ($i = 0; $i -lt 30; $i++) {
    $dayUtc = (Get-Date).ToUniversalTime().Date.AddDays(-$i)
    $start = $dayUtc.ToString("yyyy-MM-ddT00:00:00Z")
    $end = $dayUtc.ToString("yyyy-MM-ddT23:59:59Z")
    
    Write-Host "Fetching activities for: $($dayUtc.ToString('yyyy-MM-dd'))" -NoNewline
    
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
        } else {
            Write-Host " (no data)" -ForegroundColor Gray
        }
    } catch {
        Write-Host " (error)" -ForegroundColor Red
    }
}

Write-Host "Total activities retrieved: $($allActivities.Count)" -ForegroundColor Green

# -----------------------------------------------------------------------------
# Step 3: Identify Active Users
# -----------------------------------------------------------------------------
Write-Host "`n=== Analyzing User Activity ===" -ForegroundColor Cyan

# Get unique active users
$activeUsers = $allActivities | 
    Select-Object -ExpandProperty UserId -Unique |
    Where-Object { $_ -ne $null }

Write-Host "Active users (30 days): $($activeUsers.Count)"

# -----------------------------------------------------------------------------
# Step 4: Cross-Reference and Identify Inactive Licensed Users
# -----------------------------------------------------------------------------
Write-Host "`n=== License Utilization Analysis ===" -ForegroundColor Cyan

$utilizationReport = foreach ($user in $licensedUsers) {
    $isActive = $activeUsers -contains $user.UserPrincipalName
    
    # Count activities for this user
    $userActivities = $allActivities | Where-Object { $_.UserId -eq $user.UserPrincipalName }
    $activityCount = if ($userActivities) { @($userActivities).Count } else { 0 }
    
    # Get last activity date
    $lastActivity = if ($userActivities) {
        ($userActivities | Sort-Object CreationTime -Descending | Select-Object -First 1).CreationTime
    } else {
        "No activity"
    }
    
    [PSCustomObject]@{
        DisplayName       = $user.DisplayName
        UserPrincipalName = $user.UserPrincipalName
        LicenseType       = $user.LicenseType
        AccountEnabled    = $user.AccountEnabled
        IsActive30Days    = $isActive
        ActivityCount     = $activityCount
        LastActivity      = $lastActivity
    }
}

# Export full report
$utilizationReport | Export-Csv -Path "LicenseUtilization.csv" -NoTypeInformation -Encoding UTF8
Write-Host "Full report exported to: LicenseUtilization.csv" -ForegroundColor Green

# -----------------------------------------------------------------------------
# Step 5: Summary Statistics
# -----------------------------------------------------------------------------
Write-Host "`n=== Utilization Summary ===" -ForegroundColor Cyan

$proUsers = $utilizationReport | Where-Object { $_.LicenseType -eq "Power BI Pro" }
$ppuUsers = $utilizationReport | Where-Object { $_.LicenseType -eq "Power BI Premium Per User" }

$activeProUsers = ($proUsers | Where-Object { $_.IsActive30Days }).Count
$activePpuUsers = ($ppuUsers | Where-Object { $_.IsActive30Days }).Count

Write-Host "`nPower BI Pro:" -ForegroundColor Yellow
Write-Host "  Total Licensed:    $($proUsers.Count)"
Write-Host "  Active (30 days):  $activeProUsers"
Write-Host "  Inactive:          $($proUsers.Count - $activeProUsers)"
if ($proUsers.Count -gt 0) {
    Write-Host "  Utilization Rate:  $([math]::Round(($activeProUsers / $proUsers.Count) * 100, 1))%"
}

Write-Host "`nPower BI Premium Per User:" -ForegroundColor Yellow
Write-Host "  Total Licensed:    $($ppuUsers.Count)"
Write-Host "  Active (30 days):  $activePpuUsers"
Write-Host "  Inactive:          $($ppuUsers.Count - $activePpuUsers)"
if ($ppuUsers.Count -gt 0) {
    Write-Host "  Utilization Rate:  $([math]::Round(($activePpuUsers / $ppuUsers.Count) * 100, 1))%"
}

# Inactive users list
$inactiveUsers = $utilizationReport | Where-Object { -not $_.IsActive30Days -and $_.LicenseType -ne "Power BI Free" }

Write-Host "`n=== Inactive Licensed Users (Potential License Recovery) ===" -ForegroundColor Yellow
Write-Host "Found $($inactiveUsers.Count) inactive Pro/PPU users"

if ($inactiveUsers.Count -gt 0) {
    $inactiveUsers | Export-Csv -Path "InactiveLicensedUsers.csv" -NoTypeInformation -Encoding UTF8
    Write-Host "Exported to: InactiveLicensedUsers.csv" -ForegroundColor Green
    
    # Show first 20
    $inactiveUsers | 
        Select-Object DisplayName, UserPrincipalName, LicenseType, AccountEnabled, LastActivity |
        Select-Object -First 20 |
        Format-Table -AutoSize
}

# Cost analysis (approximate)
$monthlyCostPro = 10  # USD per user per month
$monthlyCostPpu = 20  # USD per user per month

$potentialSavings = (($proUsers.Count - $activeProUsers) * $monthlyCostPro) + 
                    (($ppuUsers.Count - $activePpuUsers) * $monthlyCostPpu)

Write-Host "`n=== Potential Monthly Savings ===" -ForegroundColor Cyan
Write-Host "Inactive Pro licenses:  $($proUsers.Count - $activeProUsers) x `$$monthlyCostPro = `$$((($proUsers.Count - $activeProUsers) * $monthlyCostPro))"
Write-Host "Inactive PPU licenses:  $($ppuUsers.Count - $activePpuUsers) x `$$monthlyCostPpu = `$$((($ppuUsers.Count - $activePpuUsers) * $monthlyCostPpu))"
Write-Host "Total Potential Savings: `$$potentialSavings/month" -ForegroundColor Green
