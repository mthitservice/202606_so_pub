# Day 3: Data Connectivity and Gateway Configuration

This document covers connecting data sources and configuring gateways in Microsoft Fabric.

---

## Data Source Types

```
Data Sources:
├── Cloud Sources (Direct)
│   ├── Azure SQL Database
│   ├── Azure Synapse Analytics
│   ├── Azure Data Lake Storage
│   ├── SharePoint Online
│   ├── Dataverse
│   └── SaaS apps (Dynamics, Salesforce)
├── On-Premises Sources (via Gateway)
│   ├── SQL Server
│   ├── Oracle
│   ├── File Servers
│   ├── SharePoint On-Prem
│   └── SAP HANA/BW
└── Fabric Native
    ├── Lakehouse
    ├── Warehouse
    └── KQL Database
```

---

## Connection Modes

| Mode | Data Location | Refresh | Best For |
|------|---------------|---------|----------|
| **Import** | Copied to Fabric | Scheduled | Small-medium data |
| **DirectQuery** | Stays at source | Real-time | Large data, fresh data |
| **Direct Lake** | OneLake (Delta) | Real-time | Fabric Lakehouses |
| **Composite** | Mixed | Mixed | Hybrid scenarios |

---

## Authentication Methods

| Source Type | Auth Methods |
|-------------|--------------|
| Azure Services | OAuth, Service Principal, Managed Identity |
| SQL Databases | SQL Auth, Windows Auth, OAuth |
| File Sources | OAuth, Account Key, SAS |
| SaaS Apps | OAuth, API Keys |
| On-Premises | Windows Auth (via Gateway) |

---

## Connecting to Azure SQL Database

### Steps

1. Open Power BI Desktop
2. Get Data → Azure → Azure SQL Database
3. Enter connection details:
   ```
   Server: yourserver.database.windows.net
   Database: YourDatabase
   ```
4. Choose authentication:
   - Microsoft account (OAuth)
   - Database (SQL auth)
5. Select tables
6. Choose Import or DirectQuery
7. Load data

---

## Connecting to SharePoint List

### Steps

1. Get Data → Online Services → SharePoint Online List
2. Enter SharePoint site URL:
   ```
   https://yourtenant.sharepoint.com/sites/yoursite
   ```
3. Sign in with organizational account
4. Select list(s) to import
5. Transform in Power Query if needed

### Common Power Query Transformations

```powerquery
// Remove system columns
let
    Source = SharePoint.Tables("https://contoso.sharepoint.com/sites/data"),
    SelectList = Source{[Title="SalesList"]}[Items],
    RemoveColumns = Table.RemoveColumns(SelectList,
        {"ContentTypeId", "Modified", "Created", "Author", "Editor",
         "_UIVersionString", "Attachments", "GUID", "ServerRedirectedEmbedUri"})
in
    RemoveColumns
```

---

## Direct Lake Mode

**Direct Lake** is a Fabric-specific connection mode that:

- Connects directly to Delta tables in OneLake
- Provides real-time data without scheduled refresh
- Offers near-Import performance
- Only works with Fabric Lakehouses/Warehouses

**Benefits:** Combines Import performance with DirectQuery freshness.

---

## Gateway Architecture

```
                    ┌─────────────────┐
                    │  Power BI       │
                    │  Service        │
                    └────────┬────────┘
                             │ HTTPS (443)
                             │ Outbound only
                    ┌────────▼────────┐
┌──────────┐        │  Azure Service  │
│ On-Prem  │◄───────│  Bus Relay      │
│ Gateway  │        └─────────────────┘
└────┬─────┘
     │
┌────▼─────────────────────────────────┐
│         On-Premises Network          │
│  ┌──────┐  ┌──────┐  ┌──────────┐   │
│  │ SQL  │  │ File │  │ Oracle   │   │
│  │Server│  │Server│  │ Database │   │
│  └──────┘  └──────┘  └──────────┘   │
└──────────────────────────────────────┘
```

---

## Gateway Types

| Type | Users | Capabilities | Use Case |
|------|-------|--------------|----------|
| Standard | Multiple | DirectQuery, Scheduled Refresh | Production |
| Personal | Single | Scheduled Refresh only | Development |
| VNet Gateway | N/A | Azure private endpoints | Azure resources |

---

## Gateway Installation Requirements

| Requirement | Minimum | Recommended |
|-------------|---------|-------------|
| OS | Windows Server 2019 | Windows Server 2022 |
| .NET | 4.7.2 | Latest |
| CPU | 4 cores | 8+ cores |
| RAM | 8 GB | 16+ GB |
| Disk | 20 GB | SSD |
| Network | 1 Gbps | 10 Gbps |

---

## Gateway High Availability Setup

```
Gateway Cluster
├── Primary Gateway (Server A)
│   ├── All data sources configured
│   └── Handles load
└── Secondary Gateway (Server B)
    ├── Same data sources
    └── Failover/Load balancing
```

### Installation Steps

1. Install gateway on first server (creates cluster)
2. Install gateway on additional servers
3. During registration, select "Add to existing cluster"
4. Enter same recovery key
5. Configure same data sources on each node

---

## Network Requirements

The gateway uses **outbound HTTPS (port 443)** only:

- No inbound ports required
- Connects to Azure Service Bus Relay
- All traffic is encrypted
- Works through most firewalls

**Optional ports (if 443 blocked):**
- 5671, 5672 (AMQP)
- 9350-9354 (TCP)

---

## Gateway Log Locations

```
%LocalAppData%\Microsoft\On-premises data gateway\
├── GatewayLogs\
│   ├── Report_*.log (activity logs)
│   └── Errors_*.log (error details)
└── Gateway_*.log (main logs)
```

Also check: Windows Event Viewer → Applications and Services Logs → On-premises data gateway

---

## Common Gateway Issues

| Issue | Cause | Solution |
|-------|-------|----------|
| Connection timeout | Network latency | Optimize queries, add indexes |
| Authentication failed | Wrong credentials | Update data source credentials |
| Gateway offline | Service stopped | Restart gateway service |
| Memory exceeded | Large datasets | Scale up server RAM |
| High CPU | Complex queries | Optimize queries, add gateway nodes |

---

## Warehouse vs. Lakehouse Decision Guide

| Choose Warehouse when... | Choose Lakehouse when... |
|--------------------------|--------------------------|
| Need enterprise-scale relational analytics | Have highly unstructured data |
| Star/snowflake schema design | Spark is primary development tool |
| Full T-SQL DDL/DML support required | Need flexibility for varied file formats |
| Corporate data marts and governed models | Data science and ML workloads |
