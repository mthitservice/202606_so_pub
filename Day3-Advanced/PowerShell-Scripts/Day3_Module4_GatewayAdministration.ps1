# =============================================================================
# Day 3 - Module 4 - Gateway Administration Scripts
# =============================================================================
# Scripts for managing On-Premises Data Gateways

# Connect to Power BI
Connect-PowerBIServiceAccount

Write-Host "=== Gateway Administration ===" -ForegroundColor Cyan

# -----------------------------------------------------------------------------
# Exercise 4.1: List All Gateways (Admin Only)
# -----------------------------------------------------------------------------
Write-Host "`n=== Available Gateways ===" -ForegroundColor Yellow

# Get all gateways in the organization
try {
    $gateways = Invoke-PowerBIRestMethod -Url "gateways" -Method Get | ConvertFrom-Json
    
    if ($gateways.value) {
        Write-Host "Found $($gateways.value.Count) gateway(s):" -ForegroundColor Green
        
        $gateways.value | ForEach-Object {
            Write-Host "`n  Gateway: $($_.name)" -ForegroundColor Cyan
            Write-Host "    ID: $($_.id)"
            Write-Host "    Type: $($_.type)"
            Write-Host "    Public Key: $($_.publicKey.exponent)..."
        }
    } else {
        Write-Host "No gateways found or you don't have access" -ForegroundColor Yellow
    }
} catch {
    Write-Host "Could not retrieve gateways: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Note: Gateway management requires appropriate permissions" -ForegroundColor Yellow
}

# -----------------------------------------------------------------------------
# Exercise 4.2: Get Gateway Data Sources
# -----------------------------------------------------------------------------
function Get-GatewayDataSources {
    param([string]$GatewayId)
    
    Write-Host "`n=== Data Sources for Gateway ===" -ForegroundColor Yellow
    
    try {
        $datasources = Invoke-PowerBIRestMethod -Url "gateways/$GatewayId/datasources" -Method Get | ConvertFrom-Json
        
        if ($datasources.value) {
            $datasources.value | ForEach-Object {
                [PSCustomObject]@{
                    Name = $_.datasourceName
                    Type = $_.datasourceType
                    ConnectionDetails = $_.connectionDetails
                    CredentialType = $_.credentialType
                    Id = $_.id
                }
            } | Format-Table -AutoSize
        }
    } catch {
        Write-Host "Could not retrieve data sources: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Example usage (uncomment and provide gateway ID):
# Get-GatewayDataSources -GatewayId "your-gateway-id"

# -----------------------------------------------------------------------------
# Exercise 4.3: Check Gateway Status
# -----------------------------------------------------------------------------
function Get-GatewayStatus {
    param([string]$GatewayId)
    
    Write-Host "`n=== Gateway Status ===" -ForegroundColor Yellow
    
    try {
        $gateway = Invoke-PowerBIRestMethod -Url "gateways/$GatewayId" -Method Get | ConvertFrom-Json
        
        Write-Host "Gateway: $($gateway.name)" -ForegroundColor Cyan
        Write-Host "Type: $($gateway.type)"
        Write-Host "Version: $($gateway.gatewayAnnotation)" 
        
        # Check cluster members
        if ($gateway.gatewayMembers) {
            Write-Host "`nCluster Members:"
            $gateway.gatewayMembers | ForEach-Object {
                $status = if ($_.status -eq "Online") { "Green" } else { "Red" }
                Write-Host "  - $($_.name): $($_.status)" -ForegroundColor $status
            }
        }
    } catch {
        Write-Host "Could not retrieve gateway status: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# -----------------------------------------------------------------------------
# Exercise 4.4: Map Dataset to Gateway
# -----------------------------------------------------------------------------
function Set-DatasetGatewayBinding {
    param(
        [Parameter(Mandatory=$true)][string]$WorkspaceId,
        [Parameter(Mandatory=$true)][string]$DatasetId,
        [Parameter(Mandatory=$true)][string]$GatewayId,
        [Parameter(Mandatory=$true)][string]$DatasourceId
    )
    
    Write-Host "`n=== Binding Dataset to Gateway ===" -ForegroundColor Yellow
    
    $body = @{
        gatewayObjectId = $GatewayId
        datasourceObjectIds = @($DatasourceId)
    } | ConvertTo-Json
    
    try {
        $url = "groups/$WorkspaceId/datasets/$DatasetId/Default.BindToGateway"
        Invoke-PowerBIRestMethod -Url $url -Method Post -Body $body
        
        Write-Host "Successfully bound dataset to gateway" -ForegroundColor Green
    } catch {
        Write-Host "Failed to bind: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# -----------------------------------------------------------------------------
# Exercise 4.4: Get Dataset Gateway Bindings
# -----------------------------------------------------------------------------
function Get-DatasetGatewayBinding {
    param(
        [Parameter(Mandatory=$true)][string]$WorkspaceId,
        [Parameter(Mandatory=$true)][string]$DatasetId
    )
    
    Write-Host "`n=== Dataset Gateway Bindings ===" -ForegroundColor Yellow
    
    try {
        $url = "groups/$WorkspaceId/datasets/$DatasetId/Default.GetBoundGatewayDatasources"
        $bindings = Invoke-PowerBIRestMethod -Url $url -Method Get | ConvertFrom-Json
        
        if ($bindings.value) {
            $bindings.value | ForEach-Object {
                [PSCustomObject]@{
                    DatasourceName = $_.datasourceName
                    DatasourceType = $_.datasourceType
                    GatewayId = $_.gatewayId
                    ConnectionDetails = $_.connectionDetails
                }
            } | Format-Table -AutoSize
        } else {
            Write-Host "No gateway bindings found" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "Could not retrieve bindings: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# -----------------------------------------------------------------------------
# Gateway Health Check Script
# -----------------------------------------------------------------------------
Write-Host "`n=== Gateway Health Check Function ===" -ForegroundColor Cyan

function Test-GatewayHealth {
    param([string]$GatewayId)
    
    $healthReport = @{
        GatewayId = $GatewayId
        Timestamp = Get-Date
        Status = "Unknown"
        Issues = @()
    }
    
    try {
        $gateway = Invoke-PowerBIRestMethod -Url "gateways/$GatewayId" -Method Get | ConvertFrom-Json
        
        # Check gateway status
        $healthReport.Status = "Healthy"
        
        # Check cluster members
        $offlineMembers = $gateway.gatewayMembers | Where-Object { $_.status -ne "Online" }
        if ($offlineMembers) {
            $healthReport.Issues += "Offline members: $($offlineMembers.name -join ', ')"
            $healthReport.Status = "Warning"
        }
        
        # Get data sources and check credentials
        $datasources = Invoke-PowerBIRestMethod -Url "gateways/$GatewayId/datasources" -Method Get | ConvertFrom-Json
        
        $expiredCreds = $datasources.value | Where-Object { $_.credentialDetails.credentialType -eq "NotSpecified" }
        if ($expiredCreds) {
            $healthReport.Issues += "Data sources with credential issues: $($expiredCreds.Count)"
            $healthReport.Status = "Critical"
        }
        
    } catch {
        $healthReport.Status = "Error"
        $healthReport.Issues += $_.Exception.Message
    }
    
    return $healthReport
}

# -----------------------------------------------------------------------------
# Gateway Installation Checklist
# -----------------------------------------------------------------------------
Write-Host "`n=== Gateway Installation Checklist ===" -ForegroundColor Yellow

Write-Host @"

Pre-Installation:
[ ] Windows Server 2019/2022 prepared
[ ] Dedicated server (not shared with other workloads)
[ ] .NET Framework 4.7.2+ installed
[ ] 8GB+ RAM available (16GB recommended)
[ ] Fast network connection to data sources
[ ] Outbound HTTPS (443) to Azure allowed
[ ] Service account created with data source access

Installation Steps:
1. Download: https://aka.ms/on-premises-data-gateway-installer
2. Run as Administrator
3. Select "On-premises data gateway (recommended)"
4. Sign in with organizational account
5. Enter gateway name (e.g., "GW-Production-01")
6. Create recovery key (SAVE THIS SECURELY!)
7. Complete registration

Post-Installation:
[ ] Verify gateway appears in Power BI Admin Portal
[ ] Add data sources to gateway
[ ] Test data source connections
[ ] Set up monitoring/alerting
[ ] Document recovery key location

For High Availability:
[ ] Install second gateway on different server
[ ] Register to same cluster (use recovery key)
[ ] Verify load balancing works
[ ] Test failover scenario
"@
