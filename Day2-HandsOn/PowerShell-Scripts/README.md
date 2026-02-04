# PowerShell Scripts for Fabric Administration

This folder contains PowerShell scripts for managing Microsoft Fabric workspaces, monitoring, and automation.

## Prerequisites

```powershell
# Install the Power BI Management module
Install-Module -Name MicrosoftPowerBIMgmt -Scope CurrentUser -Force
```

## Scripts Overview

| Script | Purpose |
|--------|---------|
| `Get-ActivityLog.ps1` | Export Power BI activity logs for governance |
| `Get-WorkspaceInventory.ps1` | Create a complete workspace inventory |

## Usage

### Authentication

All scripts require authentication to Power BI Service:

```powershell
Connect-PowerBIServiceAccount
```

### Activity Log Export

Exports activity events for the last N days (max 28 days of history available):

```powershell
.\Get-ActivityLog.ps1
```

### Workspace Inventory

Creates a CSV report of all workspaces with item counts:

```powershell
.\Get-WorkspaceInventory.ps1
```

## Output Files

- `ActivityLog.csv` - Activity events with user actions, timestamps, and details
- `WorkspaceInventory.csv` - Workspace details including report/dataset counts

## Related Documentation

- [MicrosoftPowerBIMgmt Module](https://docs.microsoft.com/en-us/powershell/power-bi/overview)
- [Power BI Activity Events](https://docs.microsoft.com/en-us/power-bi/admin/service-admin-auditing)

---

*Compiled by Michael Lindner*
