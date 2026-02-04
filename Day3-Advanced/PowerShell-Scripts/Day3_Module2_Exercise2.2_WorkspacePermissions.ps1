# =============================================================================
# Day 3 - Module 2 - Exercise 2.2: Configuring Workspace Permissions
# =============================================================================
# Apply group-based permissions to Fabric workspaces

# Connect to Power BI
Connect-PowerBIServiceAccount

Write-Host "=== Workspace Permission Configuration ===" -ForegroundColor Cyan

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------
# Replace these with your actual workspace and group IDs

$workspaceId = "your-workspace-id"  # GUID of the workspace

# Group names (must exist in Entra ID)
$adminGroup       = "SG-Fabric-Finance-Admins"
$contributorGroup = "SG-Fabric-Finance-Contributors"
$viewerGroup      = "SG-Fabric-Finance-Viewers"

# -----------------------------------------------------------------------------
# Function: Get Group ID from Name
# -----------------------------------------------------------------------------
function Get-EntraGroupId {
    param([string]$GroupName)
    
    # Requires Microsoft.Graph module
    $group = Get-MgGroup -Filter "displayName eq '$GroupName'" -ErrorAction SilentlyContinue
    return $group.Id
}

# -----------------------------------------------------------------------------
# Function: Add Group to Workspace
# -----------------------------------------------------------------------------
function Add-GroupToWorkspace {
    param(
        [string]$WorkspaceId,
        [string]$GroupId,
        [string]$GroupName,
        [ValidateSet("Admin", "Member", "Contributor", "Viewer")]
        [string]$AccessRight
    )
    
    Write-Host "Adding '$GroupName' as $AccessRight..." -NoNewline
    
    try {
        # Use identifier as the group ID (Object ID from Entra)
        Add-PowerBIWorkspaceUser -Scope Organization `
            -Id $WorkspaceId `
            -Identifier $GroupId `
            -AccessRight $AccessRight `
            -PrincipalType Group
        
        Write-Host " [OK]" -ForegroundColor Green
        return $true
    } catch {
        Write-Host " [FAILED]" -ForegroundColor Red
        Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# -----------------------------------------------------------------------------
# Main Script
# -----------------------------------------------------------------------------

# Verify workspace exists
Write-Host "`nVerifying workspace..." -ForegroundColor Cyan
$workspace = Get-PowerBIWorkspace -Scope Organization -Id $workspaceId -ErrorAction SilentlyContinue

if (-not $workspace) {
    Write-Host "ERROR: Workspace not found: $workspaceId" -ForegroundColor Red
    exit
}

Write-Host "Workspace: $($workspace.Name)" -ForegroundColor Green

# Connect to Graph for group lookup
Write-Host "`nConnecting to Microsoft Graph for group lookup..." -ForegroundColor Cyan
Connect-MgGraph -Scopes "Group.Read.All" -NoWelcome

# Get group IDs
Write-Host "`nResolving group IDs..." -ForegroundColor Cyan

$adminGroupId = Get-EntraGroupId -GroupName $adminGroup
$contributorGroupId = Get-EntraGroupId -GroupName $contributorGroup
$viewerGroupId = Get-EntraGroupId -GroupName $viewerGroup

if (-not $adminGroupId) { Write-Host "WARNING: Admin group not found: $adminGroup" -ForegroundColor Yellow }
if (-not $contributorGroupId) { Write-Host "WARNING: Contributor group not found: $contributorGroup" -ForegroundColor Yellow }
if (-not $viewerGroupId) { Write-Host "WARNING: Viewer group not found: $viewerGroup" -ForegroundColor Yellow }

# Apply permissions
Write-Host "`nApplying workspace permissions..." -ForegroundColor Cyan

$results = @()

if ($adminGroupId) {
    $success = Add-GroupToWorkspace -WorkspaceId $workspaceId -GroupId $adminGroupId -GroupName $adminGroup -AccessRight "Admin"
    $results += [PSCustomObject]@{ Group = $adminGroup; Role = "Admin"; Status = if ($success) {"Success"} else {"Failed"} }
}

if ($contributorGroupId) {
    $success = Add-GroupToWorkspace -WorkspaceId $workspaceId -GroupId $contributorGroupId -GroupName $contributorGroup -AccessRight "Contributor"
    $results += [PSCustomObject]@{ Group = $contributorGroup; Role = "Contributor"; Status = if ($success) {"Success"} else {"Failed"} }
}

if ($viewerGroupId) {
    $success = Add-GroupToWorkspace -WorkspaceId $workspaceId -GroupId $viewerGroupId -GroupName $viewerGroup -AccessRight "Viewer"
    $results += [PSCustomObject]@{ Group = $viewerGroup; Role = "Viewer"; Status = if ($success) {"Success"} else {"Failed"} }
}

# Summary
Write-Host "`n=== Permission Assignment Summary ===" -ForegroundColor Cyan
$results | Format-Table -AutoSize

# Show current workspace access
Write-Host "`n=== Current Workspace Access ===" -ForegroundColor Cyan
$workspaceWithUsers = Get-PowerBIWorkspace -Scope Organization -Id $workspaceId -Include Users

$workspaceWithUsers.Users | 
    Select-Object @{N='Name';E={$_.Identifier}}, 
                  @{N='Type';E={$_.PrincipalType}}, 
                  @{N='Role';E={$_.GroupUserAccessRight}} |
    Format-Table -AutoSize
