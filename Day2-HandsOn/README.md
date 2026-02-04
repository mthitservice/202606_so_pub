# Day 2: Hands-On Labs

This folder contains practical exercises, scripts, and projects developed during the coaching session.

---

## Contents

### Projects

| Folder | Description |
|--------|-------------|
| [KeyRotation-AzureFunction](KeyRotation-AzureFunction/) | Azure Function for automated Service Principal key rotation |
| [PowerShell-Scripts](PowerShell-Scripts/) | PowerShell scripts for Fabric administration |

### Documentation

| Document | Topics |
|----------|--------|
| [KQL-Monitoring-Guide.md](KQL-Monitoring-Guide.md) | KQL fundamentals, workspace monitoring, query analysis |

---

## Topics Covered

### Module 3: API Access and Automation
- Service Principal authentication
- REST API integration with Fabric
- Automated credential rotation

### Module 4: Workspace Monitoring
- Enabling workspace monitoring
- KQL query fundamentals
- SQL to KQL translation
- Performance analysis queries

### Module 5: Scripting
- PowerShell module installation
- Activity log extraction
- Workspace inventory reports

---

## Project: Key Rotation Azure Function

Automates Service Principal secret rotation for Fabric Mirror connections:

1. Creates new client secret in Entra ID
2. Stores secret in Azure Key Vault
3. Updates Fabric Mirror Connection
4. Cleans up old secrets

See [KeyRotation-AzureFunction/README.md](KeyRotation-AzureFunction/README.md) for details.

---

## Prerequisites

- Microsoft Fabric workspace (Premium or Trial)
- Azure subscription (for Azure Function deployment)
- PowerShell with MicrosoftPowerBIMgmt module
- .NET 8.0 SDK (for Azure Function development)

---

*Compiled by Michael Lindner*
