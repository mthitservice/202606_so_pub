# ============================================================
# Get-ActivityLog.ps1
# Export Power BI Activity Events for Governance and Auditing
# ============================================================

# Install (optional) - recommended: CurrentUser scope to avoid admin prompts
# Install-Module -Name MicrosoftPowerBIMgmt -Scope CurrentUser -Force

# Login to Power BI Service
Connect-PowerBIServiceAccount

# Configuration
$daysBack = 7  # How many days back (max ~28 days history available)
$outFile = "ActivityLog.csv"

# Remove existing output file if present
if (Test-Path $outFile) { 
    Remove-Item $outFile -Force 
}

$all = @()

for ($i = 0; $i -lt $daysBack; $i++) {
    # Use UTC day boundaries (same UTC day!)
    $dayUtc = (Get-Date).ToUniversalTime().Date.AddDays(-$i)

    $start = $dayUtc.ToString("yyyy-MM-ddT00:00:00Z")
    $end   = $dayUtc.ToString("yyyy-MM-ddT23:59:59Z")

    Write-Host "Fetching: $start -> $end"

    # Get JSON string and convert
    $json = Get-PowerBIActivityEvent -StartDateTime $start -EndDateTime $end -ResultType JsonString
    
    if ($json) {
        $events = $json | ConvertFrom-Json
        if ($events) { 
            $all += $events 
        }
    }
}

# Export to CSV
$all | Export-Csv -Path $outFile -NoTypeInformation -Encoding UTF8

Write-Host "Exported $($all.Count) activities to $outFile" -ForegroundColor Green

# Summary statistics
Write-Host "`n=== Activity Summary ===" -ForegroundColor Cyan
$all | Group-Object Activity | Sort-Object Count -Descending | Select-Object -First 10 Name, Count | Format-Table
