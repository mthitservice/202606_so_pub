# =============================================================================
# Day 3 - Module 2 - Exercise 2.4: Object-Level Security (OLS)
# =============================================================================
# OLS hides tables or columns from specific roles
# NOTE: OLS is configured via XMLA endpoint (requires Premium/Fabric)

Write-Host "=== Object-Level Security (OLS) Configuration ===" -ForegroundColor Cyan

# -----------------------------------------------------------------------------
# Part 1: Understanding OLS Concepts
# -----------------------------------------------------------------------------
Write-Host @"

=== Object-Level Security (OLS) Overview ===

OLS hides entire tables or columns from users. Unlike RLS which filters rows,
OLS completely removes visibility of metadata.

Use Cases:
- Hide salary columns from non-HR users
- Hide sensitive PII columns
- Restrict access to draft/unpublished tables

Configuration Methods:
1. Power BI Desktop (Modeling > Manage Roles > Column permissions)
2. Tabular Editor (third-party tool)
3. XMLA endpoint (programmatic)

"@ -ForegroundColor Yellow

# -----------------------------------------------------------------------------
# Part 2: XMLA Script for OLS Configuration
# -----------------------------------------------------------------------------
Write-Host "=== XMLA Script Template for OLS ===" -ForegroundColor Cyan

$xmlaOlsScript = @'
// XMLA Script to create OLS role
// Run this via SSMS or Azure Data Studio connected to XMLA endpoint

{
  "createOrReplace": {
    "object": {
      "database": "YourDataset",
      "role": "NonHRUsers"
    },
    "role": {
      "name": "NonHRUsers",
      "description": "Users who cannot see HR-sensitive columns",
      "modelPermission": "read",
      "tablePermissions": [
        {
          "name": "Employees",
          "metadataPermission": "read",
          "columnPermissions": [
            {
              "name": "Salary",
              "metadataPermission": "none"
            },
            {
              "name": "SSN",
              "metadataPermission": "none"
            },
            {
              "name": "DateOfBirth",
              "metadataPermission": "none"
            }
          ]
        }
      ]
    }
  }
}
'@

Write-Host $xmlaOlsScript

# -----------------------------------------------------------------------------
# Part 3: Tabular Editor C# Script (Alternative Method)
# -----------------------------------------------------------------------------
Write-Host "`n=== Tabular Editor Script for OLS ===" -ForegroundColor Cyan

$tabularEditorScript = @'
// Tabular Editor C# Script
// Run this in Tabular Editor connected to your model

// Create or get the role
var roleName = "NonHRUsers";
var role = Model.Roles.FirstOrDefault(r => r.Name == roleName);
if (role == null) {
    role = Model.AddRole(roleName);
    role.ModelPermission = ModelPermission.Read;
}

// Set column permissions
var employeesTable = Model.Tables["Employees"];
var columnsToHide = new[] { "Salary", "SSN", "DateOfBirth" };

foreach (var colName in columnsToHide) {
    var column = employeesTable.Columns[colName];
    if (column != null) {
        // Set OLS - None means hidden
        column.SetMetadataPermission(role, MetadataPermission.None);
    }
}

// Save changes
Model.SaveChanges();
'@

Write-Host $tabularEditorScript

# -----------------------------------------------------------------------------
# Part 4: Testing OLS
# -----------------------------------------------------------------------------
Write-Host "`n=== Testing OLS ===" -ForegroundColor Yellow

Write-Host @"

To test OLS:

1. In Power BI Desktop:
   - Modeling > View as
   - Select the OLS role
   - Hidden columns should not appear in field list

2. In Power BI Service:
   - Connect via Analyze in Excel
   - Hidden columns won't be visible in pivot table field list

3. Via DAX Query:
   - Queries referencing hidden columns will fail
   - EVALUATE Employees[Salary] → Error for restricted role

4. Via XMLA:
   - SELECT [Salary] FROM Employees → Error
   - Metadata queries won't show hidden columns

Tip: Users will see an error if they try to access a report 
that uses hidden columns they don't have access to.
"@

# -----------------------------------------------------------------------------
# Part 5: Check Current OLS Configuration (via API)
# -----------------------------------------------------------------------------
Write-Host "`n=== Checking OLS via API (Info Only) ===" -ForegroundColor Cyan

Connect-PowerBIServiceAccount

$workspaceId = "your-workspace-id"
$datasetId   = "your-dataset-id"

# Note: Detailed OLS info requires XMLA endpoint query
# This just checks if the dataset has security configured

$headers = @{
    "Authorization" = "Bearer $(Get-PowerBIAccessToken -AsString)"
}

try {
    $datasetUrl = "https://api.powerbi.com/v1.0/myorg/groups/$workspaceId/datasets/$datasetId"
    $dataset = Invoke-RestMethod -Method Get -Uri $datasetUrl -Headers $headers
    
    Write-Host "Dataset: $($dataset.name)"
    Write-Host "Effective Identity Required: $($dataset.isEffectiveIdentityRequired)"
    Write-Host "Roles Required: $($dataset.isEffectiveIdentityRolesRequired)"
    
    if ($dataset.isEffectiveIdentityRolesRequired) {
        Write-Host "`nThis dataset has RLS/OLS configured. Connect via XMLA to see details." -ForegroundColor Yellow
    }
} catch {
    Write-Host "Note: Replace workspace and dataset IDs with actual values to query." -ForegroundColor Yellow
}
