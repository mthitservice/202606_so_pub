# =============================================================================
# Day 3 - Module 2 - Exercise 2.3: Implementing Row-Level Security (RLS)
# =============================================================================
# This script demonstrates RLS concepts and testing via XMLA/REST API
# NOTE: RLS roles are typically created in Power BI Desktop. This script
# shows how to manage and test RLS programmatically.

# Connect to Power BI
Connect-PowerBIServiceAccount

Write-Host "=== Row-Level Security Management ===" -ForegroundColor Cyan

# Configuration
$workspaceId = "your-workspace-id"
$datasetId   = "your-dataset-id"

# -----------------------------------------------------------------------------
# Part 1: Understanding RLS DAX Expressions
# -----------------------------------------------------------------------------
Write-Host "`n=== RLS DAX Expression Examples ===" -ForegroundColor Yellow

$rlsExamples = @"

1. STATIC RLS - Filter by fixed value:
   ----------------------------------------
   Table: Sales
   DAX: [Region] = "East"
   
   Result: Users in this role only see East region data

2. DYNAMIC RLS - Filter by user identity:
   ----------------------------------------
   Table: Sales
   DAX: [SalesPersonEmail] = USERPRINCIPALNAME()
   
   Result: Each user sees only their own sales data

3. DYNAMIC RLS with Lookup Table:
   ----------------------------------------
   Table: Sales
   DAX: 
   [Region] IN 
       CALCULATETABLE(
           VALUES(UserRegions[Region]),
           UserRegions[UserEmail] = USERPRINCIPALNAME()
       )
   
   Result: Users see data for regions assigned to them in UserRegions table

4. DYNAMIC RLS with Manager Hierarchy:
   ----------------------------------------
   Table: Sales
   DAX:
   PATHCONTAINS(
       [ManagerPath],
       LOOKUPVALUE(Employees[EmployeeId], Employees[Email], USERPRINCIPALNAME())
   )
   
   Result: Managers see their own data plus all subordinates' data

"@
Write-Host $rlsExamples

# -----------------------------------------------------------------------------
# Part 2: Get RLS Role Members via API
# -----------------------------------------------------------------------------
Write-Host "=== Retrieving RLS Role Members ===" -ForegroundColor Cyan

$headers = @{
    "Authorization" = "Bearer $(Get-PowerBIAccessToken -AsString)"
    "Content-Type"  = "application/json"
}

# Get dataset roles
try {
    $rolesUrl = "https://api.powerbi.com/v1.0/myorg/groups/$workspaceId/datasets/$datasetId"
    $dataset = Invoke-RestMethod -Method Get -Uri $rolesUrl -Headers $headers
    
    Write-Host "Dataset: $($dataset.name)"
    Write-Host "Has RLS: $($dataset.isEffectiveIdentityRequired)"
    Write-Host "Has OLS: $($dataset.isEffectiveIdentityRolesRequired)"
    
} catch {
    Write-Host "Could not retrieve dataset info: $($_.Exception.Message)" -ForegroundColor Yellow
}

# Get role assignments
try {
    $roleUsersUrl = "https://api.powerbi.com/v1.0/myorg/groups/$workspaceId/datasets/$datasetId/users"
    $roleUsers = Invoke-RestMethod -Method Get -Uri $roleUsersUrl -Headers $headers
    
    Write-Host "`nRLS Role Assignments:"
    if ($roleUsers.value) {
        $roleUsers.value | Select-Object identifier, principalType, datasetUserAccessRight | Format-Table -AutoSize
    } else {
        Write-Host "No RLS role assignments found" -ForegroundColor Yellow
    }
    
} catch {
    Write-Host "Could not retrieve role assignments: $($_.Exception.Message)" -ForegroundColor Yellow
}

# -----------------------------------------------------------------------------
# Part 3: Add User to RLS Role via API
# -----------------------------------------------------------------------------
function Add-UserToRlsRole {
    param(
        [string]$WorkspaceId,
        [string]$DatasetId,
        [string]$UserEmail,
        [string]$RoleName
    )
    
    $body = @{
        identifier = $UserEmail
        principalType = "User"
        datasetUserAccessRight = "Read"
    } | ConvertTo-Json
    
    $addUrl = "https://api.powerbi.com/v1.0/myorg/groups/$WorkspaceId/datasets/$DatasetId/users"
    
    try {
        Invoke-RestMethod -Method Post -Uri $addUrl -Headers $headers -Body $body
        Write-Host "Added $UserEmail to RLS role: $RoleName" -ForegroundColor Green
    } catch {
        Write-Host "Failed to add user: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# -----------------------------------------------------------------------------
# Part 4: Test RLS as Another User (Power BI Desktop Required)
# -----------------------------------------------------------------------------
Write-Host "`n=== Testing RLS in Power BI Desktop ===" -ForegroundColor Yellow
Write-Host @"

To test RLS in Power BI Desktop:

1. Open your .pbix file
2. Go to Modeling tab > "View as" button
3. Select the role you want to test
4. Optionally check "Other user" and enter a test email
5. Click OK to view data as that role/user
6. Verify data filtering is correct
7. Click "Stop viewing" to return to normal view

Tip: Test with multiple user emails to verify dynamic RLS works correctly.
"@

# -----------------------------------------------------------------------------
# Part 5: Sample XMLA Script for RLS (Advanced)
# -----------------------------------------------------------------------------
Write-Host "`n=== XMLA RLS Definition (Reference) ===" -ForegroundColor Yellow

$xmlaExample = @'
{
  "createOrReplace": {
    "object": {
      "database": "YourDataset",
      "role": "SalesRegionFilter"
    },
    "role": {
      "name": "SalesRegionFilter",
      "modelPermission": "read",
      "tablePermissions": [
        {
          "name": "Sales",
          "filterExpression": "[SalesPersonEmail] = USERPRINCIPALNAME()"
        }
      ]
    }
  }
}
'@

Write-Host $xmlaExample
Write-Host "`nNote: XMLA endpoint requires Premium/Fabric capacity" -ForegroundColor Yellow
