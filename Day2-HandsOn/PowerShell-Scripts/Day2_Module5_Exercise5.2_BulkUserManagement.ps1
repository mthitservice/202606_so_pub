# =============================================================================
# Day 2 - Module 5 - Exercise 5.2: Bulk User Management
# =============================================================================
# Add or remove users from multiple workspaces using a CSV input file

# Connect to Power BI
Connect-PowerBIServiceAccount

# -----------------------------------------------------------------------------
# Input File Format (UserChanges.csv)
# -----------------------------------------------------------------------------
# WorkspaceId,UserEmail,Role,Action
# 12345678-1234-1234-1234-123456789abc,user1@domain.com,Member,Add
# 12345678-1234-1234-1234-123456789abc,user2@domain.com,Viewer,Add
# 87654321-4321-4321-4321-cba987654321,user3@domain.com,Admin,Remove

# Create sample input file if it doesn't exist
$sampleFile = "UserChanges_Sample.csv"
if (-not (Test-Path $sampleFile)) {
    $sampleContent = @"
WorkspaceId,UserEmail,Role,Action
your-workspace-id,user1@domain.com,Member,Add
your-workspace-id,user2@domain.com,Viewer,Add
your-workspace-id,user3@domain.com,Contributor,Add
"@
    $sampleContent | Out-File -FilePath $sampleFile -Encoding UTF8
    Write-Host "Created sample file: $sampleFile" -ForegroundColor Yellow
    Write-Host "Edit this file with your actual workspace IDs and user emails, then run again." -ForegroundColor Yellow
}

# -----------------------------------------------------------------------------
# Main Script
# -----------------------------------------------------------------------------
$inputFile = "UserChanges.csv"
$outputFile = "UserChangeResults.csv"

if (-not (Test-Path $inputFile)) {
    Write-Host "ERROR: Input file '$inputFile' not found" -ForegroundColor Red
    Write-Host "Create a CSV with columns: WorkspaceId, UserEmail, Role, Action" -ForegroundColor Yellow
    Write-Host "See '$sampleFile' for example format" -ForegroundColor Yellow
    exit
}

Write-Host "=== Bulk User Management ===" -ForegroundColor Cyan

# Load changes
$changes = Import-Csv -Path $inputFile
Write-Host "Loaded $($changes.Count) user changes from $inputFile" -ForegroundColor Green

# Validate input
$validRoles = @("Admin", "Member", "Contributor", "Viewer")
$validActions = @("Add", "Remove")

$invalidEntries = $changes | Where-Object {
    $_.Role -notin $validRoles -or $_.Action -notin $validActions
}

if ($invalidEntries) {
    Write-Host "ERROR: Invalid entries found" -ForegroundColor Red
    Write-Host "Valid Roles: $($validRoles -join ', ')"
    Write-Host "Valid Actions: $($validActions -join ', ')"
    $invalidEntries | Format-Table
    exit
}

# Process changes
$results = @()

foreach ($change in $changes) {
    $result = [PSCustomObject]@{
        WorkspaceId = $change.WorkspaceId
        User        = $change.UserEmail
        Role        = $change.Role
        Action      = $change.Action
        Status      = "Pending"
        Error       = ""
        Timestamp   = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    }
    
    Write-Host "Processing: $($change.Action) $($change.UserEmail) as $($change.Role)" -NoNewline
    
    try {
        if ($change.Action -eq "Add") {
            Add-PowerBIWorkspaceUser -Scope Organization `
                -Id $change.WorkspaceId `
                -UserPrincipalName $change.UserEmail `
                -AccessRight $change.Role
            
            $result.Status = "Success"
            Write-Host " [OK]" -ForegroundColor Green
        }
        elseif ($change.Action -eq "Remove") {
            Remove-PowerBIWorkspaceUser -Scope Organization `
                -Id $change.WorkspaceId `
                -UserPrincipalName $change.UserEmail
            
            $result.Status = "Success"
            Write-Host " [OK]" -ForegroundColor Green
        }
    }
    catch {
        $result.Status = "Failed"
        $result.Error = $_.Exception.Message
        Write-Host " [FAILED]" -ForegroundColor Red
        Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    $results += $result
    
    # Avoid throttling
    Start-Sleep -Milliseconds 300
}

# Export results
$results | Export-Csv -Path $outputFile -NoTypeInformation -Encoding UTF8
Write-Host "`nResults exported to: $outputFile" -ForegroundColor Green

# Summary
Write-Host "`n=== Results Summary ===" -ForegroundColor Cyan
$results | Group-Object Status | Select-Object Name, Count | Format-Table -AutoSize

# Show failures if any
$failures = $results | Where-Object { $_.Status -eq "Failed" }
if ($failures) {
    Write-Host "=== Failed Operations ===" -ForegroundColor Red
    $failures | Select-Object User, Action, Error | Format-Table -AutoSize
}
