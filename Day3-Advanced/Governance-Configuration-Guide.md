# Day 3: Governance Configuration

This document covers platform governance settings for Microsoft Fabric.

---

## Governance Framework

```
Fabric Governance Pillars:
├── Access Control
│   ├── Tenant settings
│   ├── Workspace permissions
│   └── Item-level security
├── Data Protection
│   ├── Sensitivity labels
│   ├── Encryption
│   └── Data loss prevention
├── Compliance
│   ├── Audit logs
│   ├── Activity tracking
│   └── Regulatory reports
└── Quality
    ├── Endorsements
    ├── Lineage tracking
    └── Impact analysis
```

---

## Critical Tenant Settings

| Category | Setting | Recommendation |
|----------|---------|----------------|
| **Export** | Export to Excel | Enable for specific groups |
| **Export** | Export to CSV | Enable for specific groups |
| **Export** | Export to PDF/PPT | Enable for all |
| **Sharing** | External sharing | Disable or restrict |
| **Sharing** | Email subscriptions | Enable for specific groups |
| **Developer** | Service principals | Enable for specific groups |
| **Developer** | Custom visuals | Disable unapproved |

---

## Security Configuration Matrix

**By User Type:**

| Setting | Business Users | Analysts | Developers | Admins |
|---------|---------------|----------|------------|--------|
| Export data | ❌ | ✅ | ✅ | ✅ |
| Create workspaces | ❌ | ✅ | ✅ | ✅ |
| Use APIs | ❌ | ❌ | ✅ | ✅ |
| Embed reports | ❌ | ❌ | ✅ | ✅ |
| External sharing | ❌ | ❌ | ❌ | ✅ |

---

## Domain Configuration

**Benefits of Domains:**
- Logical grouping of workspaces
- Delegated administration
- Data mesh patterns
- Simplified governance

**Domain Structure Example:**

```
Fabric Tenant
├── Domain: Finance
│   ├── Workspace: Finance-Reports
│   ├── Workspace: Finance-Dev
│   └── Domain Admin: FinanceBI Team
├── Domain: Sales
│   ├── Workspace: Sales-Dashboards
│   ├── Workspace: Sales-Analytics
│   └── Domain Admin: Sales Ops
└── Domain: HR
    ├── Workspace: HR-People-Analytics
    └── Domain Admin: HR Analytics Team
```

---

## Endorsement Framework

| Level | Badge | Meaning | Set By |
|-------|-------|---------|--------|
| None | - | Default state | - |
| Promoted | ⬆️ | Recommended by owner | Content owner |
| Certified | ✓ | Verified by governance | Designated certifiers |

### Certification Process

1. Content owner requests certification
2. Governance team reviews:
   - Data quality
   - Documentation
   - Refresh reliability
   - Security compliance
3. Certification granted or feedback provided
4. Periodic re-certification

### Certification Checklist

| Criteria | Required | Verification |
|----------|----------|--------------|
| Data source documented | ✅ | Check description |
| Refresh working | ✅ | 30 days success |
| RLS implemented (if needed) | ✅ | Test access |
| Sensitivity label applied | ✅ | Check properties |
| Owner documented | ✅ | Check workspace |
| Business glossary | ✅ | Check descriptions |

---

## Sensitivity Labels

### Label Inheritance Flow

```
Data Source
    ↓ (label applied)
Semantic Model → inherits label
    ↓
Report → inherits from dataset
    ↓
Dashboard → inherits from reports
    ↓
Export → carries label
```

Labels can be manually upgraded (more restrictive) but not downgraded.

### Implementation Steps

1. Configure labels in Microsoft Purview
2. Scope labels to "Files & other data assets"
3. Publish labels to users
4. Enable in Fabric Admin Portal
5. Apply labels to content

---

## Data Loss Prevention (DLP)

Integration with Microsoft Purview DLP:

```
DLP Policy Components:
├── Conditions (what to detect)
│   ├── Credit card numbers
│   ├── Social security numbers
│   └── Custom sensitive types
├── Actions (what to do)
│   ├── Block sharing
│   ├── Require justification
│   └── Notify admin
└── Locations
    ├── Power BI / Fabric
    ├── SharePoint
    └── OneDrive
```

---

## Tenant Settings Configuration

### Export and Sharing Settings

```
Export and sharing settings:
├── Export to Excel
│   ├── Status: Enabled
│   └── Apply to: Specific security groups
│       └── "SG-Fabric-DataExport-Allowed"
├── Export to CSV
│   ├── Status: Enabled
│   └── Apply to: Specific security groups
│       └── "SG-Fabric-DataExport-Allowed"
├── Share to Teams
│   ├── Status: Enabled
│   └── Apply to: Entire organization
└── External sharing
    ├── Status: Disabled
    └── Apply to: None
```

### Developer Settings

```
Developer settings:
├── Service principals
│   ├── Status: Enabled
│   └── Apply to: Specific security groups
│       └── "SG-Fabric-ServicePrincipals"
├── Allow XMLA endpoints
│   ├── Status: Enabled
│   └── Apply to: Specific security groups
│       └── "SG-Fabric-Advanced-Users"
└── Users can try paid Fabric features
    ├── Status: Disabled
    └── Apply to: None
```

---

## Audit Log Configuration

### Enable in Microsoft Purview

1. Verify auditing enabled in Purview → Audit → Audit policies
2. Ensure Power BI/Fabric activities are captured
3. Create alert policies for sensitive activities

### Alert Policy Example

- Activity: "Exported Power BI report"
- Condition: Specific users or all users
- Action: Email notification

### Weekly Review Checklist

- [ ] Large exports
- [ ] Unusual access patterns
- [ ] Failed access attempts
- [ ] Administrative changes

---

## Production Governance Checklist

- [ ] Restrict export to specific groups
- [ ] Disable external sharing (or restrict)
- [ ] Enable audit logging
- [ ] Configure sensitivity labels
- [ ] Set up domains for departments
- [ ] Define certification process
- [ ] Install gateway cluster (if on-prem data)
- [ ] Document all tenant settings
- [ ] Create governance dashboard
- [ ] Establish regular review cadence

---

## PowerShell Commands Reference

| Operation | Command |
|-----------|---------|
| List all workspaces | `Get-PowerBIWorkspace -Scope Organization -All` |
| Create workspace | `New-PowerBIWorkspace -Name "Name"` |
| Add user | `Add-PowerBIWorkspaceUser -Id $id -UserPrincipalName $upn -AccessRight Admin` |
| Remove user | `Remove-PowerBIWorkspaceUser -Id $id -UserPrincipalName $upn` |
| Refresh dataset | `Invoke-PowerBIDatasetRefresh -DatasetId $id` |
| Export report | `Export-PowerBIReport -Id $id -OutFile "report.pbix"` |
