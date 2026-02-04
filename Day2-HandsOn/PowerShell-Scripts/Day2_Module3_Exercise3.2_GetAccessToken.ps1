# =============================================================================
# Day 2 - Module 3 - Exercise 3.2: Getting an Access Token
# =============================================================================
# This script demonstrates how to acquire access tokens for Power BI API

# Configuration - Replace with your values
$tenantId     = "your-tenant-id"
$clientId     = "your-client-id"
$clientSecret = "your-client-secret"
$resource     = "https://analysis.windows.net/powerbi/api"

# -----------------------------------------------------------------------------
# Method 1: Using OAuth 2.0 Client Credentials (Service Principal)
# -----------------------------------------------------------------------------
function Get-FabricAccessToken {
    param(
        [Parameter(Mandatory=$true)][string]$TenantId,
        [Parameter(Mandatory=$true)][string]$ClientId,
        [Parameter(Mandatory=$true)][string]$ClientSecret
    )
    
    $tokenEndpoint = "https://login.microsoftonline.com/$TenantId/oauth2/token"
    
    $body = @{
        grant_type    = "client_credentials"
        client_id     = $ClientId
        client_secret = $ClientSecret
        resource      = "https://analysis.windows.net/powerbi/api"
    }
    
    try {
        $response = Invoke-RestMethod -Method Post -Uri $tokenEndpoint -Body $body
        return $response
    } catch {
        Write-Error "Failed to acquire token: $($_.Exception.Message)"
        return $null
    }
}

# -----------------------------------------------------------------------------
# Method 2: Using OAuth 2.0 v2 Endpoint (with scope)
# -----------------------------------------------------------------------------
function Get-FabricAccessTokenV2 {
    param(
        [Parameter(Mandatory=$true)][string]$TenantId,
        [Parameter(Mandatory=$true)][string]$ClientId,
        [Parameter(Mandatory=$true)][string]$ClientSecret
    )
    
    $tokenEndpoint = "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token"
    
    $body = @{
        grant_type    = "client_credentials"
        client_id     = $ClientId
        client_secret = $ClientSecret
        scope         = "https://analysis.windows.net/powerbi/api/.default"
    }
    
    try {
        $response = Invoke-RestMethod -Method Post -Uri $tokenEndpoint -Body $body
        return $response
    } catch {
        Write-Error "Failed to acquire token: $($_.Exception.Message)"
        return $null
    }
}

# -----------------------------------------------------------------------------
# Acquire Token
# -----------------------------------------------------------------------------
Write-Host "=== Acquiring Access Token ===" -ForegroundColor Cyan

$tokenResponse = Get-FabricAccessToken -TenantId $tenantId -ClientId $clientId -ClientSecret $clientSecret

if ($tokenResponse) {
    $accessToken = $tokenResponse.access_token
    
    Write-Host "SUCCESS: Token acquired!" -ForegroundColor Green
    Write-Host "Token Type:  $($tokenResponse.token_type)"
    Write-Host "Expires In:  $($tokenResponse.expires_in) seconds"
    Write-Host "Scope:       $($tokenResponse.scope)" 
    Write-Host "Token (first 50 chars): $($accessToken.Substring(0, 50))..."
    
    # Calculate expiration time
    $expirationTime = (Get-Date).AddSeconds($tokenResponse.expires_in)
    Write-Host "Expires At:  $($expirationTime.ToString('yyyy-MM-dd HH:mm:ss'))"
    
    # Store for use in other exercises
    $global:FabricAccessToken = $accessToken
    $global:FabricTokenExpires = $expirationTime
    
    Write-Host "`nToken stored in `$global:FabricAccessToken" -ForegroundColor Yellow
    
} else {
    Write-Host "FAILED: Could not acquire token" -ForegroundColor Red
}

# -----------------------------------------------------------------------------
# Token Refresh Helper Function
# -----------------------------------------------------------------------------
function Test-TokenExpired {
    if (-not $global:FabricTokenExpires) { return $true }
    return (Get-Date) -gt $global:FabricTokenExpires.AddMinutes(-5)
}

function Ensure-FabricToken {
    param(
        [string]$TenantId,
        [string]$ClientId,
        [string]$ClientSecret
    )
    
    if (Test-TokenExpired) {
        Write-Host "Token expired or expiring soon. Refreshing..." -ForegroundColor Yellow
        $tokenResponse = Get-FabricAccessToken -TenantId $TenantId -ClientId $ClientId -ClientSecret $ClientSecret
        if ($tokenResponse) {
            $global:FabricAccessToken = $tokenResponse.access_token
            $global:FabricTokenExpires = (Get-Date).AddSeconds($tokenResponse.expires_in)
            Write-Host "Token refreshed successfully" -ForegroundColor Green
        }
    }
    return $global:FabricAccessToken
}

# -----------------------------------------------------------------------------
# Create Reusable Headers
# -----------------------------------------------------------------------------
function Get-FabricHeaders {
    return @{
        "Authorization" = "Bearer $($global:FabricAccessToken)"
        "Content-Type"  = "application/json"
    }
}

Write-Host "`n=== Helper Functions Available ===" -ForegroundColor Cyan
Write-Host "Get-FabricAccessToken     - Acquire new token"
Write-Host "Test-TokenExpired         - Check if token is expired"
Write-Host "Ensure-FabricToken        - Refresh token if needed"
Write-Host "Get-FabricHeaders         - Get authorization headers"
