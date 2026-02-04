# =============================================================================
# Day 2 - Module 3 - Exercise 3.1: Setting Up Service Principal Authentication
# =============================================================================
# This script helps configure a Service Principal for Fabric API access
# Run this AFTER creating the App Registration in Azure Portal

# Install required modules
Install-Module -Name MicrosoftPowerBIMgmt -Scope CurrentUser -Force
Install-Module -Name Az.Accounts -Scope CurrentUser -Force

# -----------------------------------------------------------------------------
# Step 1: Document your Service Principal details
# -----------------------------------------------------------------------------
# After creating the App Registration in Azure Portal, fill in these values:

$config = @{
    TenantId     = "your-tenant-id"        # Directory (tenant) ID
    ClientId     = "your-client-id"        # Application (client) ID
    ClientSecret = "your-client-secret"    # Client secret value
}

# Save configuration to secure file (for demo purposes)
Write-Host "=== Service Principal Configuration ===" -ForegroundColor Cyan
Write-Host "Tenant ID:     $($config.TenantId)"
Write-Host "Client ID:     $($config.ClientId)"
Write-Host "Secret Length: $($config.ClientSecret.Length) characters"

# -----------------------------------------------------------------------------
# Step 2: Verify Admin Portal Settings are Correct
# -----------------------------------------------------------------------------
Write-Host "`n=== Admin Portal Checklist ===" -ForegroundColor Cyan
$checklist = @(
    "[ ] Service principals can use Fabric APIs = Enabled",
    "[ ] Service principals can access read-only admin APIs = Enabled",
    "[ ] Your SP is in the allowed security group",
    "[ ] Your SP has workspace access (if needed)"
)
$checklist | ForEach-Object { Write-Host $_ }

# -----------------------------------------------------------------------------
# Step 3: Test Service Principal Authentication
# -----------------------------------------------------------------------------
Write-Host "`n=== Testing Authentication ===" -ForegroundColor Cyan

# Resource URL for Power BI API
$resource = "https://analysis.windows.net/powerbi/api"

# Token endpoint
$tokenEndpoint = "https://login.microsoftonline.com/$($config.TenantId)/oauth2/token"

# Request body
$body = @{
    grant_type    = "client_credentials"
    client_id     = $config.ClientId
    client_secret = $config.ClientSecret
    resource      = $resource
}

try {
    $response = Invoke-RestMethod -Method Post -Uri $tokenEndpoint -Body $body
    Write-Host "SUCCESS: Access token acquired!" -ForegroundColor Green
    Write-Host "Token type: $($response.token_type)"
    Write-Host "Expires in: $($response.expires_in) seconds"
    
    # Store token for subsequent exercises
    $global:FabricAccessToken = $response.access_token
    Write-Host "`nToken stored in `$global:FabricAccessToken for use in next exercises" -ForegroundColor Yellow
    
} catch {
    Write-Host "ERROR: Failed to acquire token" -ForegroundColor Red
    Write-Host $_.Exception.Message
    Write-Host "`nCommon issues:" -ForegroundColor Yellow
    Write-Host "1. Check Tenant ID, Client ID, and Secret are correct"
    Write-Host "2. Verify app has correct API permissions in Azure Portal"
    Write-Host "3. Ensure admin consent was granted for permissions"
}

# -----------------------------------------------------------------------------
# Step 4: Test API Access
# -----------------------------------------------------------------------------
if ($global:FabricAccessToken) {
    Write-Host "`n=== Testing API Access ===" -ForegroundColor Cyan
    
    $headers = @{
        "Authorization" = "Bearer $($global:FabricAccessToken)"
        "Content-Type"  = "application/json"
    }
    
    try {
        # Test with a simple API call
        $workspacesUrl = "https://api.powerbi.com/v1.0/myorg/groups"
        $workspaces = Invoke-RestMethod -Method Get -Uri $workspacesUrl -Headers $headers
        
        Write-Host "SUCCESS: API access verified!" -ForegroundColor Green
        Write-Host "Workspaces accessible: $($workspaces.value.Count)"
        
    } catch {
        Write-Host "ERROR: API call failed" -ForegroundColor Red
        Write-Host $_.Exception.Message
        
        if ($_.Exception.Response.StatusCode -eq 403) {
            Write-Host "`nThe Service Principal needs workspace access." -ForegroundColor Yellow
            Write-Host "Add it to workspaces via: Workspace Settings > Access > Add the SP" -ForegroundColor Yellow
        }
    }
}
