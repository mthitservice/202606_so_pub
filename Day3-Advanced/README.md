# Day 3: Advanced Topics

This folder contains materials covering data connectivity, gateway configuration, and governance in Microsoft Fabric.

---

## Contents

### Documentation

| Document | Topics |
|----------|--------|
| [DataConnectivity-Gateway-Guide.md](DataConnectivity-Gateway-Guide.md) | Connection modes, gateway setup, authentication |
| [Governance-Configuration-Guide.md](Governance-Configuration-Guide.md) | Tenant settings, domains, endorsements, DLP |

---

## Topics Covered

### Module 3: Data Connectivity
- Cloud vs. on-premises data sources
- Import, DirectQuery, and Direct Lake modes
- Azure SQL and SharePoint connections
- Authentication methods

### Module 4: Gateway Configuration
- Gateway architecture and types
- High availability setup
- Network requirements
- Troubleshooting

### Module 5: Governance
- Tenant settings configuration
- Domain structure
- Endorsement and certification
- Sensitivity labels
- Data loss prevention (DLP)
- Audit logging

---

## Key Takeaways

1. **Connectivity** = Cloud (direct) + On-prem (gateway)
2. **Gateway** = Outbound only, cluster for HA
3. **Governance** = Tenant settings + Domains + Endorsements + DLP
4. **Security** = Entra ID + Workspace Roles + RLS/OLS + Labels

---

## Prerequisites

- Completed Day 1 and Day 2 materials
- Working Fabric environment
- Admin access for governance configuration

---

*Compiled by Michael Lindner*
