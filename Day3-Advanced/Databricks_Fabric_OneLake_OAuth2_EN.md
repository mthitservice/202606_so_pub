# Databricks Tables in Microsoft Fabric via OAuth2 and OneLake

This guide describes how to make Databricks tables available in Microsoft Fabric - **without Service Principal and without password rotation**.

## 🎯 Goal

Use Databricks data in Fabric Lakehouses with:
- ✅ **OAuth2 authentication** (User-based or Managed Identity)
- ✅ **OneLake as central storage**
- ✅ **Caching for performance**
- ❌ **No Mirroring Connector**
- ❌ **No Service Principal with secret rotation**

---

## ⚠️ Problem: Spark Cluster Startup Times

Traditional Databricks clusters require **5-15 minutes startup time**. This is unacceptable for interactive users!

### Solution Strategies

| Strategy | Startup Time | Cost | Recommendation |
|----------|--------------|------|----------------|
| **Databricks Serverless SQL** | ~10 seconds | Pay-per-Query | ⭐⭐⭐ Best Option |
| **Fabric DirectLake** | Instant | Included in Capacity | ⭐⭐⭐ For BI |
| **Pre-sync to OneLake** | Instant (Data in Fabric) | Databricks only for ETL | ⭐⭐⭐ Recommended |
| **Serverless Compute (Preview)** | ~30 seconds | Pay-per-Use | ⭐⭐ For Notebooks |
| **Instance Pools** | 1-2 minutes | Idle costs | ⭐⭐ Compromise |
| **Always-On Cluster** | Instant | Very expensive | ❌ Not recommended |

---

## 📋 Overview of Approaches

| Approach | Authentication | Password Rotation | Cluster Startup Time | Complexity |
|----------|----------------|-------------------|----------------------|------------|
| **OneLake Shortcut to ADLS** | OAuth2 / Managed Identity | ❌ No | ✅ None (Fabric reads) | ⭐ Simple |
| **Databricks Unity Catalog + Fabric** | OAuth2 | ❌ No | ⚠️ On query | ⭐⭐ Medium |
| **Delta Lake write to OneLake** | Managed Identity | ❌ No | ✅ None (Data cached) | ⭐⭐ Medium |

| **Serverless SQL Warehouse** | OAuth2 | ❌ No | ✅ ~10 seconds | ⭐⭐ Medium |

---

## 🚀 Approach 0: Serverless - No Cluster Startup Time (RECOMMENDED)

### Why Serverless?

| Classic Cluster | Serverless |
|-----------------|------------|
| 5-15 min startup | 10-30 sec |
| Idle costs | Pay-per-Use |
| Manual scaling | Auto-Scaling |
| Cluster management | No management |

### Option A: Databricks Serverless SQL Warehouse

**For SQL queries and BI tools - startup time ~10 seconds!**

```sql
-- SQL Warehouse query (no cluster start needed)
SELECT * FROM unity_catalog.schema.sales_table
WHERE date >= '2026-01-01'
```

**Setup:**
1. Open Databricks Workspace
2. **SQL Warehouses** → **Create SQL Warehouse**
3. Select **Serverless**
4. Size as needed (XS for tests)

**Connection from Fabric:**
```python
# Fabric Notebook - Connection to Serverless SQL Warehouse
jdbc_url = "jdbc:databricks://<workspace>.azuredatabricks.net:443/default"
jdbc_url += ";transportMode=http;ssl=1;AuthMech=11;Auth_Flow=0"
jdbc_url += ";httpPath=/sql/1.0/warehouses/<warehouse-id>"

df = spark.read.format("jdbc") \
    .option("url", jdbc_url) \
    .option("query", "SELECT * FROM sales") \
    .load()
```

### Option B: Databricks Serverless Compute (for Notebooks)

**For notebook development - startup time ~30 seconds!**

In Databricks Workspace:
1. **Compute** → **Create Compute**
2. Enable **Serverless** (if available in your region)
3. Connect notebook

```python
# Notebook runs on Serverless Compute
df = spark.read.table("catalog.schema.table")
# No waiting!
```

### Option C: Pre-sync to OneLake (Best Solution for Users)

**Users only access Fabric - Databricks runs only at night for ETL!**

```
┌─────────────┐   Night Job   ┌──────────────┐    Instant    ┌─────────────┐
│  Databricks │ ─────────────► │   OneLake    │ ◄────────────► │    User     │
│   (Night)   │   Delta Sync   │   (Cache)    │   DirectLake  │  (Power BI) │
└─────────────┘                └──────────────┘                └─────────────┘
```

**Advantage:** Users never wait for cluster startup!

---

## 🔧 Approach 1: OneLake Shortcut to ADLS Gen2 (Recommended)

### Concept

Databricks writes Delta tables to ADLS Gen2, Fabric accesses them via **Shortcut**.

```
┌─────────────┐     Delta Lake     ┌──────────────┐     Shortcut     ┌─────────────┐
│  Databricks │ ─────────────────► │  ADLS Gen2   │ ◄───────────────► │   Fabric    │
│   Cluster   │                    │  (Storage)   │    (OAuth2)       │  Lakehouse  │
└─────────────┘                    └──────────────┘                   └─────────────┘
```

### Step 1: Set up ADLS Gen2 Storage Account

```powershell
# Create Storage Account
az storage account create `
  --name "dlsdatabricksfabric" `
  --resource-group "FabricRG" `
  --location "westeurope" `
  --sku "Standard_LRS" `
  --kind "StorageV2" `
  --hns true  # Hierarchical Namespace for ADLS Gen2

# Create Container
az storage container create `
  --name "delta-tables" `
  --account-name "dlsdatabricksfabric"
```

### Step 2: Databricks writes to ADLS (with OAuth2)

In Databricks Notebook:

```python
# OAuth2 configuration for ADLS Gen2
storage_account = "dlsdatabricksfabric"
container = "delta-tables"

# Databricks OAuth2 (User Delegation or Managed Identity)
spark.conf.set(
    f"fs.azure.account.auth.type.{storage_account}.dfs.core.windows.net", 
    "OAuth"
)
spark.conf.set(
    f"fs.azure.account.oauth.provider.type.{storage_account}.dfs.core.windows.net",
    "org.apache.hadoop.fs.azurebfs.oauth2.MsiTokenProvider"  # Managed Identity
)

# Write Delta Table
df = spark.read.table("your_database.your_table")
df.write.format("delta") \
    .mode("overwrite") \
    .save(f"abfss://{container}@{storage_account}.dfs.core.windows.net/sales_data")
```

### Step 3: Create Fabric Shortcut

**In Fabric Portal:**

1. Open your **Lakehouse** in Microsoft Fabric
2. Click **Get data** → **New shortcut**
3. Select **Azure Data Lake Storage Gen2**
4. Enter the URL:
   ```
   https://dlsdatabricksfabric.dfs.core.windows.net/delta-tables
   ```
5. Authentication: **Organizational account** (OAuth2)
6. Click **Create**

**Via REST API:**

```powershell
# Create Fabric Shortcut via REST API
$workspaceId = "your-workspace-id"
$lakehouseId = "your-lakehouse-id"
$accessToken = (Get-AzAccessToken -ResourceUrl "https://api.fabric.microsoft.com").Token

$body = @{
    path = "Tables/sales_data"
    target = @{
        type = "AdlsGen2"
        adlsGen2 = @{
            location = "https://dlsdatabricksfabric.dfs.core.windows.net"
            subpath = "/delta-tables/sales_data"
            connectionId = $null  # Uses current user credentials
        }
    }
} | ConvertTo-Json -Depth 5

Invoke-RestMethod -Uri "https://api.fabric.microsoft.com/v1/workspaces/$workspaceId/lakehouses/$lakehouseId/shortcuts" `
    -Method POST `
    -Headers @{ 
        "Authorization" = "Bearer $accessToken"
        "Content-Type" = "application/json" 
    } `
    -Body $body
```

### Step 4: Enable Caching in Fabric

```sql
-- In Fabric SQL Endpoint
-- Automatic caching for frequently queried data
SELECT * FROM lakehouse.sales_data
OPTION (USE HINT('ENABLE_RESULT_SET_CACHING'));
```

---

## 🔧 Approach 2: Databricks Unity Catalog with OneLake

### Concept

Unity Catalog can directly access OneLake as an external storage location.

### Step 1: Determine OneLake Path

```
Format: https://onelake.dfs.fabric.microsoft.com/<workspace-name>/<lakehouse-name>/Tables/
```

### Step 2: Create Unity Catalog External Location

```sql
-- In Databricks SQL
CREATE EXTERNAL LOCATION onelake_fabric
URL 'abfss://<workspace-id>@onelake.dfs.fabric.microsoft.com/<lakehouse-id>/Tables'
WITH (STORAGE CREDENTIAL fabric_credential);
```

### Step 3: Storage Credential with OAuth2

```sql
-- Managed Identity Credential (no secrets!)
CREATE STORAGE CREDENTIAL fabric_credential
WITH (AZURE_MANAGED_IDENTITY = '/subscriptions/<sub-id>/resourceGroups/<rg>/providers/Microsoft.ManagedIdentity/userAssignedIdentities/<identity-name>');
```

### Step 4: Create External Table

```sql
-- Create Delta Table in OneLake
CREATE TABLE unity_catalog.fabric_schema.sales_data
LOCATION 'abfss://<workspace-id>@onelake.dfs.fabric.microsoft.com/<lakehouse-id>/Tables/sales_data'
AS SELECT * FROM databricks_catalog.source_schema.sales_table;
```

---

## 🔧 Approach 4: Write Delta Lake directly to OneLake

### Concept

Databricks writes directly to OneLake, Fabric reads the data natively.

### Databricks Notebook

```python
# OneLake configuration
workspace_id = "your-fabric-workspace-id"
lakehouse_id = "your-lakehouse-id"

# Managed Identity for OneLake access
spark.conf.set(
    "fs.azure.account.auth.type.onelake.dfs.fabric.microsoft.com",
    "OAuth"
)
spark.conf.set(
    "fs.azure.account.oauth.provider.type.onelake.dfs.fabric.microsoft.com",
    "org.apache.hadoop.fs.azurebfs.oauth2.MsiTokenProvider"
)

# Write directly to OneLake
onelake_path = f"abfss://{workspace_id}@onelake.dfs.fabric.microsoft.com/{lakehouse_id}/Tables/sales_data"

df = spark.read.table("source_database.sales")
df.write.format("delta") \
    .mode("overwrite") \
    .option("overwriteSchema", "true") \
    .save(onelake_path)
```

### Set up Permissions

```powershell
# Grant Databricks Managed Identity access to OneLake
# In Fabric Admin Portal or via REST API

$workspaceId = "your-workspace-id"
$databricksManagedIdentityId = "databricks-managed-identity-object-id"

# Assign workspace role (Contributor or Member)
# This enables write access to the Lakehouse
```

---

## 🔐 OAuth2 Authentication Options

### Option A: Managed Identity (Recommended for Automation)

| Advantages | Disadvantages |
|------------|---------------|
| No secrets | Requires Azure setup |
| Automatic token rotation | Only for Azure resources |
| No manual management | |

### Option B: User Delegation (Interactive)

| Advantages | Disadvantages |
|------------|---------------|
| Easy to set up | Requires user interaction |
| Standard OAuth2 flow | Token expires |
| No Service Principals | Not for automation |

### Option C: Workload Identity (AKS/Kubernetes)

| Advantages | Disadvantages |
|------------|---------------|
| No secrets | Only for container workloads |
| Federated credentials | More complex setup |

---

## 📊 Caching Strategies in Fabric

### 1. Automatic Caching (Default)

Fabric automatically caches frequently queried data in the Lakehouse.

### 2. Materialized Views

```sql
-- Materialized view for frequent queries
CREATE MATERIALIZED VIEW mv_sales_summary AS
SELECT 
    Region,
    ProductCategory,
    SUM(Revenue) as TotalRevenue,
    COUNT(*) as TransactionCount
FROM lakehouse.sales_data
GROUP BY Region, ProductCategory;
```

### 3. Delta Lake Z-Ordering for Query Performance

```python
# In Databricks before writing
from delta.tables import DeltaTable

deltaTable = DeltaTable.forPath(spark, onelake_path)
deltaTable.optimize().executeZOrderBy("Region", "Date")
```

### 4. Fabric Semantic Model Caching

In Power BI Semantic Model:
- **Import Mode**: Full caching
- **DirectLake**: Optimized in-memory caching for Parquet/Delta

---

## ⚡ Performance Tips

### Databricks Side

```python
# Partitioning for large tables
df.write.format("delta") \
    .partitionBy("year", "month") \
    .mode("overwrite") \
    .save(onelake_path)

# Update statistics
spark.sql(f"ANALYZE TABLE delta.`{onelake_path}` COMPUTE STATISTICS")
```

### Fabric Side

```sql
-- Update statistics in Fabric
EXEC sp_update_statistics 'lakehouse.sales_data';

-- Optimized query with predicate pushdown
SELECT * FROM lakehouse.sales_data
WHERE year = 2026 AND month = 2;  -- Uses partitioning
```

---

## 🔄 Automated Sync without Rotation (Cluster-Optimized)

### Option 1: Scheduled ETL - Users Never Wait!

**Architecture:** Databricks runs only at scheduled times, users access Fabric.

```
┌──────────────────────────────────────────────────────────────────────┐
│                        NIGHT (02:00 - 05:00)                         │
│  ┌─────────────┐                      ┌──────────────┐               │
│  │  Databricks │ ───── Delta ──────► │   OneLake    │               │
│  │   Cluster   │      Sync           │   Storage    │               │
│  └─────────────┘                      └──────────────┘               │
└──────────────────────────────────────────────────────────────────────┘
                                              │
┌──────────────────────────────────────────────────────────────────────┐
│                         DAY (08:00 - 18:00)                          │
│                               │ DirectLake                           │
│                               ▼                                      │
│                        ┌──────────────┐      ┌─────────────┐         │
│                        │   Fabric     │ ◄─── │    User     │         │
│                        │  Lakehouse   │      │  (Instant!) │         │
│                        └──────────────┘      └─────────────┘         │
└──────────────────────────────────────────────────────────────────────┘
```

**Databricks Workflow (Night Job):**

```python
# Job runs at 02:00 at night - no user waits
from datetime import datetime

def nightly_sync_to_onelake():
    """
    Sync all relevant tables to OneLake.
    Users access Fabric during the day only!
    """
    tables_to_sync = [
        ("source_db.sales", "Tables/sales"),
        ("source_db.customers", "Tables/customers"),
        ("source_db.products", "Tables/products"),
    ]
    
    onelake_base = "abfss://<workspace-id>@onelake.dfs.fabric.microsoft.com/<lakehouse-id>"
    
    for source_table, target_path in tables_to_sync:
        print(f"[{datetime.now()}] Syncing {source_table}...")
        df = spark.read.table(source_table)
        df.write.format("delta") \
            .mode("overwrite") \
            .option("overwriteSchema", "true") \
            .save(f"{onelake_base}/{target_path}")
        print(f"[{datetime.now()}] Completed {source_table}")

nightly_sync_to_onelake()
```

**Databricks Job Schedule:**
1. **Workflows** → **Create Job**
2. **Schedule:** `0 2 * * *` (daily 02:00)
3. **Cluster:** Job Cluster (starts automatically, terminates after job)

### Option 2: Serverless SQL for Ad-Hoc Queries

```python
# If users need live data → Serverless SQL Warehouse
# Startup time only ~10 seconds!

from databricks import sql

connection = sql.connect(
    server_hostname="<workspace>.azuredatabricks.net",
    http_path="/sql/1.0/warehouses/<serverless-warehouse-id>",
    access_token=os.getenv("DATABRICKS_TOKEN")  # OAuth2 Token
)

cursor = connection.cursor()
cursor.execute("SELECT * FROM live_data WHERE date = CURRENT_DATE")
result = cursor.fetchall()
```

### Option 3: Instance Pool for Faster Startup (Compromise)

**Reduces startup time to 1-2 minutes** (instead of 5-15 min)

```json
// Instance Pool Configuration
{
  "instance_pool_name": "fabric-sync-pool",
  "min_idle_instances": 2,
  "max_capacity": 10,
  "node_type_id": "Standard_DS3_v2",
  "idle_instance_autotermination_minutes": 30
}
```

### Option 4: Databricks Job with Managed Identity

```python
# Databricks Job (Workflow)
# Runs with Managed Identity - no secrets!

def sync_to_onelake():
    df = spark.read.table("source.sales")
    df.write.format("delta") \
        .mode("overwrite") \
        .save("abfss://...@onelake.dfs.fabric.microsoft.com/.../Tables/sales")

sync_to_onelake()
```

### Option 5: Fabric Data Pipeline

1. Create a **Data Pipeline** in Fabric
2. Add **Copy Activity**
3. Source: Azure Databricks (OAuth2)
4. Sink: Lakehouse Table
5. Schedule: As needed

---

## 🛠️ Troubleshooting

### Problem: "Access Denied" on OneLake Access

```powershell
# Check permissions
az role assignment list --scope "/subscriptions/<sub>/resourceGroups/<rg>" --assignee "<managed-identity-id>"

# Required role: "Storage Blob Data Contributor"
az role assignment create `
  --role "Storage Blob Data Contributor" `
  --assignee "<managed-identity-id>" `
  --scope "/subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.Storage/storageAccounts/<account>"
```

### Problem: Shortcut Shows No Data

1. Check if Delta format is correct
2. Make sure `_delta_log` folder exists
3. Refresh the shortcut: **Right-click → Refresh**

### Problem: Managed Identity Not Recognized

```python
# Debug: Get token
from azure.identity import ManagedIdentityCredential
credential = ManagedIdentityCredential()
token = credential.get_token("https://storage.azure.com/.default")
print(f"Token: {token.token[:50]}...")
```

---

## 📚 Summary

### Recommended Architecture for Minimal Wait Time

```
┌────────────────────────────────────────────────────────────────────────────┐
│  SOLUTION: Users never wait for Databricks Cluster!                       │
├────────────────────────────────────────────────────────────────────────────┤
│                                                                            │
│   ┌─────────────────┐     Night ETL      ┌─────────────────┐               │
│   │   Databricks    │ ─────────────────► │    OneLake      │               │
│   │  (Job Cluster)  │    Delta Sync      │   (Storage)     │               │
│   │  Starts only    │                    │                 │               │
│   │   at night      │                    │                 │               │
│   └─────────────────┘                    └────────┬────────┘               │
│                                                   │                        │
│                                                   │ DirectLake             │
│                                                   │ (Instant!)             │
│                                                   ▼                        │
│   ┌─────────────────┐                    ┌─────────────────┐               │
│   │  Serverless SQL │ ◄── Ad-Hoc ─────── │   Fabric User   │               │
│   │  (10 sec start) │    Live-Query      │    (Power BI,   │               │
│   └─────────────────┘                    │     Notebooks)  │               │
│                                          └─────────────────┘               │
│                                                                            │
└────────────────────────────────────────────────────────────────────────────┘
```

### Comparison of Methods

| Method | Password Rotation | Service Principal | Cluster Wait Time | Recommendation |
|--------|-------------------|-------------------|-------------------|----------------|
| OneLake Shortcut + Night ETL | ❌ No | ❌ No | ✅ None | ⭐⭐⭐ Best Option |
| Serverless SQL Warehouse | ❌ No | ❌ No | ✅ ~10 sec | ⭐⭐⭐ For Live Data |
| Unity Catalog + OneLake | ❌ No | ❌ No | ⚠️ On Query | ⭐⭐ With Serverless |

| Direct OneLake Write | ❌ No | ❌ No | ✅ Data cached | ⭐⭐⭐ Recommended |

### Best Strategy

1. **Standard Workload:** Nightly ETL to OneLake → Users access Fabric (no wait time!)
2. **Ad-Hoc Live Data:** Serverless SQL Warehouse (~10 seconds startup)
3. **Notebook Development:** Serverless Compute (~30 seconds startup)

**Recommendation:** Use **Nightly Sync to OneLake** with **Serverless SQL Warehouse as fallback** for the best user experience without wait times.
