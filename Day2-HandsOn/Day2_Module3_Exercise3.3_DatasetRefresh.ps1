# =============================================================================
# Day 2 - Module 3 - Exercise 3.3: Automating Dataset Refresh
# =============================================================================
# This script triggers and monitors dataset refreshes via REST API

# Prerequisites: Run Exercise 3.2 first to get $global:FabricAccessToken

# Configuration
$workspaceId = "your-workspace-id"
$datasetId   = "your-dataset-id"

# -----------------------------------------------------------------------------
# Ensure Token is Available
# -----------------------------------------------------------------------------
if (-not $global:FabricAccessToken) {
    Write-Host "ERROR: No access token found. Run Exercise 3.2 first." -ForegroundColor Red
    exit
}

$headers = @{
    "Authorization" = "Bearer $($global:FabricAccessToken)"
    "Content-Type"  = "application/json"
}

# -----------------------------------------------------------------------------
# Function: Trigger Dataset Refresh
# -----------------------------------------------------------------------------
function Start-DatasetRefresh {
    param(
        [Parameter(Mandatory=$true)][string]$WorkspaceId,
        [Parameter(Mandatory=$true)][string]$DatasetId,
        [hashtable]$Headers
    )
    
    $refreshUrl = "https://api.powerbi.com/v1.0/myorg/groups/$WorkspaceId/datasets/$DatasetId/refreshes"
    
    try {
        $response = Invoke-RestMethod -Method Post -Uri $refreshUrl -Headers $Headers
        Write-Host "SUCCESS: Refresh triggered!" -ForegroundColor Green
        return $true
    } catch {
        $statusCode = $_.Exception.Response.StatusCode.value__
        $errorMessage = $_.ErrorDetails.Message | ConvertFrom-Json
        
        Write-Host "ERROR: Refresh failed (Status: $statusCode)" -ForegroundColor Red
        
        switch ($statusCode) {
            400 { Write-Host "Bad Request - Check dataset ID" }
            401 { Write-Host "Unauthorized - Token may be expired" }
            403 { Write-Host "Forbidden - Service Principal needs access to workspace" }
            429 { 
                Write-Host "Rate Limited - Too many refreshes"
                Write-Host "Retry after: $($errorMessage.'Retry-After') seconds"
            }
        }
        return $false
    }
}

# -----------------------------------------------------------------------------
# Function: Get Refresh History
# -----------------------------------------------------------------------------
function Get-DatasetRefreshHistory {
    param(
        [Parameter(Mandatory=$true)][string]$WorkspaceId,
        [Parameter(Mandatory=$true)][string]$DatasetId,
        [hashtable]$Headers,
        [int]$Top = 10
    )
    
    $historyUrl = "https://api.powerbi.com/v1.0/myorg/groups/$WorkspaceId/datasets/$DatasetId/refreshes?`$top=$Top"
    
    try {
        $history = Invoke-RestMethod -Method Get -Uri $historyUrl -Headers $Headers
        return $history.value
    } catch {
        Write-Host "ERROR: Could not retrieve refresh history" -ForegroundColor Red
        Write-Host $_.Exception.Message
        return $null
    }
}

# -----------------------------------------------------------------------------
# Function: Wait for Refresh Completion
# -----------------------------------------------------------------------------
function Wait-DatasetRefresh {
    param(
        [Parameter(Mandatory=$true)][string]$WorkspaceId,
        [Parameter(Mandatory=$true)][string]$DatasetId,
        [hashtable]$Headers,
        [int]$TimeoutMinutes = 30,
        [int]$PollIntervalSeconds = 15
    )
    
    $startTime = Get-Date
    $timeout = $startTime.AddMinutes($TimeoutMinutes)
    
    Write-Host "Waiting for refresh to complete (timeout: $TimeoutMinutes minutes)..." -ForegroundColor Cyan
    
    while ((Get-Date) -lt $timeout) {
        $history = Get-DatasetRefreshHistory -WorkspaceId $WorkspaceId -DatasetId $DatasetId -Headers $Headers -Top 1
        
        if ($history) {
            $latestRefresh = $history[0]
            $status = $latestRefresh.status
            
            switch ($status) {
                "Completed" {
                    $duration = [Math]::Round(((Get-Date) - $startTime).TotalSeconds, 0)
                    Write-Host "SUCCESS: Refresh completed in $duration seconds" -ForegroundColor Green
                    return $latestRefresh
                }
                "Failed" {
                    Write-Host "FAILED: Refresh failed" -ForegroundColor Red
                    Write-Host "Error: $($latestRefresh.serviceExceptionJson)" -ForegroundColor Red
                    return $latestRefresh
                }
                "Cancelled" {
                    Write-Host "CANCELLED: Refresh was cancelled" -ForegroundColor Yellow
                    return $latestRefresh
                }
                "Unknown" {
                    Write-Host "." -NoNewline
                }
            }
        }
        
        Start-Sleep -Seconds $PollIntervalSeconds
    }
    
    Write-Host "`nTIMEOUT: Refresh did not complete within $TimeoutMinutes minutes" -ForegroundColor Red
    return $null
}

# -----------------------------------------------------------------------------
# Execute: Trigger Refresh and Monitor
# -----------------------------------------------------------------------------
Write-Host "=== Dataset Refresh Automation ===" -ForegroundColor Cyan
Write-Host "Workspace ID: $workspaceId"
Write-Host "Dataset ID:   $datasetId"
Write-Host ""

# Step 1: Check current refresh history
Write-Host "=== Current Refresh History ===" -ForegroundColor Cyan
$history = Get-DatasetRefreshHistory -WorkspaceId $workspaceId -DatasetId $datasetId -Headers $headers -Top 5

if ($history) {
    $history | ForEach-Object {
        $startTime = if ($_.startTime) { [DateTime]::Parse($_.startTime).ToString("yyyy-MM-dd HH:mm:ss") } else { "N/A" }
        $endTime = if ($_.endTime) { [DateTime]::Parse($_.endTime).ToString("yyyy-MM-dd HH:mm:ss") } else { "In Progress" }
        
        [PSCustomObject]@{
            RequestId = $_.requestId
            StartTime = $startTime
            EndTime   = $endTime
            Status    = $_.status
            Type      = $_.refreshType
        }
    } | Format-Table -AutoSize
}

# Step 2: Trigger new refresh
Write-Host "=== Triggering New Refresh ===" -ForegroundColor Cyan
$refreshStarted = Start-DatasetRefresh -WorkspaceId $workspaceId -DatasetId $datasetId -Headers $headers

# Step 3: Wait for completion (optional)
if ($refreshStarted) {
    Write-Host "`nDo you want to wait for the refresh to complete? (y/n): " -NoNewline -ForegroundColor Yellow
    $waitChoice = Read-Host
    
    if ($waitChoice -eq "y") {
        $result = Wait-DatasetRefresh -WorkspaceId $workspaceId -DatasetId $datasetId -Headers $headers -TimeoutMinutes 30
        
        if ($result) {
            Write-Host "`n=== Refresh Details ===" -ForegroundColor Cyan
            $result | Format-List *
        }
    }
}

# Step 4: Show updated history
Write-Host "`n=== Updated Refresh History ===" -ForegroundColor Cyan
$updatedHistory = Get-DatasetRefreshHistory -WorkspaceId $workspaceId -DatasetId $datasetId -Headers $headers -Top 3
$updatedHistory | Select-Object requestId, startTime, endTime, status, refreshType | Format-Table -AutoSize
