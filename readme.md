# Microsoft Fabric Coaching - Workshop Materials

This repository contains materials, scripts, and documentation from a three-day Microsoft Fabric coaching workshop.

---

## Repository Structure

```
├── Day1-Fundamentals/           Core concepts and learning resources
│   └── README.md                Microsoft Learn links and documentation
├── Day2-HandsOn/                Practical labs and scripts
│   ├── KeyRotation-AzureFunction/   Service Principal key rotation project
│   ├── PowerShell-Scripts/          Admin automation scripts
│   └── KQL-Monitoring-Guide.md      KQL and monitoring reference
└── Day3-Advanced/               Advanced topics and governance
    ├── DataConnectivity-Gateway-Guide.md
    └── Governance-Configuration-Guide.md
```

---

## Day Overview

### Day 1: Fundamentals
Introduction to Microsoft Fabric architecture, OneLake, Lakehouse, Data Factory, and Data Warehouse concepts. Includes curated Microsoft Learn resources and documentation links.

**Topics:**
- Microsoft Fabric architecture
- OneLake and data hierarchy
- Workload overview (Power BI, Data Factory, Data Engineering, etc.)
- Learning resources and certification paths

### Day 2: Hands-On Labs
Practical exercises with Fabric workloads including API automation, workspace monitoring, and scripting.

**Topics:**
- Service Principal authentication and key rotation
- Azure Function for automated credential management
- KQL fundamentals and workspace monitoring
- PowerShell automation scripts

### Day 3: Advanced Topics
Deep-dive sessions covering data connectivity, gateway configuration, and governance.

**Topics:**
- Data source connectivity (Import, DirectQuery, Direct Lake)
- On-premises data gateway configuration
- Tenant settings and security configuration
- Domains, endorsements, and DLP

---

## Getting Started

1. Review the [Day 1 README](Day1-Fundamentals/README.md) for foundational concepts
2. Explore hands-on projects in [Day 2](Day2-HandsOn/)
3. Reference governance guides in [Day 3](Day3-Advanced/)

---

## Requirements

- Microsoft Fabric trial or licensed workspace
- Microsoft account with appropriate permissions
- Azure subscription (for Azure Function deployment)
- PowerShell with MicrosoftPowerBIMgmt module
- Web browser (Edge or Chrome recommended)

---

## Key Projects

### Service Principal Key Rotation
Automated Azure Function that rotates Service Principal secrets and updates Fabric Mirror connections.

Location: [Day2-HandsOn/KeyRotation-AzureFunction/](Day2-HandsOn/KeyRotation-AzureFunction/)

### PowerShell Administration Scripts
Scripts for activity log extraction and workspace inventory.

Location: [Day2-HandsOn/PowerShell-Scripts/](Day2-HandsOn/PowerShell-Scripts/)

---

## Additional Resources

- [Microsoft Fabric Documentation](https://learn.microsoft.com/en-us/fabric/)
- [Fabric Learning Path](https://learn.microsoft.com/en-us/training/paths/get-started-fabric/)
- [Fabric Community](https://community.fabric.microsoft.com/)
- [Power BI REST API Reference](https://docs.microsoft.com/en-us/rest/api/power-bi/)

---

*Workshop conducted February 2026*

---

*Compiled by Michael Lindner*
