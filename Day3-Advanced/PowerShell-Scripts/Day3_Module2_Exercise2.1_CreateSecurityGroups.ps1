# =============================================================================
# Day 3 - Module 2 - Exercise 2.1: Creating Security Groups for Fabric
# =============================================================================
# This script creates Entra ID security groups for Fabric workspace access

# Prerequisites
# Install-Module Microsoft.Graph -Scope CurrentUser -Force

# Connect to Microsoft Graph with required permissions
Connect-MgGraph -Scopes "Group.ReadWrite.All", "Directory.ReadWrite.All"

Write-Host "=== Creating Fabric Security Groups ===" -ForegroundColor Cyan

# -----------------------------------------------------------------------------
# Configuration: Define your groups
# -----------------------------------------------------------------------------
$department = "Finance"  # Change this for different departments

$groups = @(
    @{
        DisplayName = "SG-Fabric-$department-Admins"
        Description = "Fabric workspace administrators for $department department"
        MailNickname = "SGFabric${department}Admins"
    },
    @{
        DisplayName = "SG-Fabric-$department-Contributors"
        Description = "Fabric workspace contributors for $department department"
        MailNickname = "SGFabric${department}Contributors"
    },
    @{
        DisplayName = "SG-Fabric-$department-Viewers"
        Description = "Fabric workspace viewers for $department department"
        MailNickname = "SGFabric${department}Viewers"
    }
)

# -----------------------------------------------------------------------------
# Create Groups
# -----------------------------------------------------------------------------
$createdGroups = @()

foreach ($group in $groups) {
    Write-Host "Creating group: $($group.DisplayName)" -NoNewline
    
    # Check if group already exists
    $existingGroup = Get-MgGroup -Filter "displayName eq '$($group.DisplayName)'" -ErrorAction SilentlyContinue
    
    if ($existingGroup) {
        Write-Host " [EXISTS]" -ForegroundColor Yellow
        $createdGroups += [PSCustomObject]@{
            DisplayName = $group.DisplayName
            GroupId     = $existingGroup.Id
            Status      = "Already Exists"
        }
    } else {
        try {
            $params = @{
                DisplayName     = $group.DisplayName
                Description     = $group.Description
                MailEnabled     = $false
                MailNickname    = $group.MailNickname
                SecurityEnabled = $true
                GroupTypes      = @()  # Empty for security groups
            }
            
            $newGroup = New-MgGroup -BodyParameter $params
            
            Write-Host " [CREATED]" -ForegroundColor Green
            $createdGroups += [PSCustomObject]@{
                DisplayName = $group.DisplayName
                GroupId     = $newGroup.Id
                Status      = "Created"
            }
        } catch {
            Write-Host " [FAILED]" -ForegroundColor Red
            Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red
            $createdGroups += [PSCustomObject]@{
                DisplayName = $group.DisplayName
                GroupId     = "N/A"
                Status      = "Failed: $($_.Exception.Message)"
            }
        }
    }
}

# -----------------------------------------------------------------------------
# Summary
# -----------------------------------------------------------------------------
Write-Host "`n=== Created Groups Summary ===" -ForegroundColor Cyan
$createdGroups | Format-Table -AutoSize

# Export group IDs for reference
$createdGroups | Export-Csv -Path "CreatedSecurityGroups.csv" -NoTypeInformation -Encoding UTF8
Write-Host "Group IDs exported to: CreatedSecurityGroups.csv" -ForegroundColor Green

# -----------------------------------------------------------------------------
# Best Practice Naming Convention Guide
# -----------------------------------------------------------------------------
Write-Host "`n=== Recommended Naming Convention ===" -ForegroundColor Yellow
Write-Host @"
Pattern: SG-Fabric-{Department/Project}-{Role}

Examples:
- SG-Fabric-Finance-Admins
- SG-Fabric-Finance-Contributors  
- SG-Fabric-Finance-Viewers
- SG-Fabric-Sales-Admins
- SG-Fabric-HR-Viewers
- SG-Fabric-ProjectX-Contributors

Group purposes:
- Admins:       Workspace administration (manage access, delete workspace)
- Members:      Create and publish content
- Contributors: Edit existing content only
- Viewers:      View content only
"@
