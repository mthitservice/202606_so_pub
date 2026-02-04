# Azure Function: Service Principal Key Rotation for Fabric Mirror

This Azure Function automatically rotates Service Principal secrets and updates the Fabric Mirror Connection for Azure Databricks.

## Purpose

Since **Fabric Mirroring does NOT support Azure Key Vault references**, you must manually enter the Service Principal secret. This function automates:

1. **Creates** a new client secret for the Service Principal
2. **Stores** the secret in Azure Key Vault
3. **Updates** the Fabric Mirror Connection (or notifies for manual update)
4. **Cleans up** old secrets (keeps last 2)

## Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                        Azure Function                                │
│                    (Timer or HTTP Trigger)                          │
└───────────────────────────┬─────────────────────────────────────────┘
                            │
    ┌───────────────────────┼───────────────────────┐
    │                       │                       │
    ▼                       ▼                       ▼
┌─────────┐         ┌─────────────┐         ┌─────────────┐
│ Entra   │         │  Key Vault  │         │   Fabric    │
│ ID      │         │             │         │   Mirror    │
│         │         │             │         │ Connection  │
│ Create  │         │   Store     │         │   Update    │
│ Secret  │         │   Secret    │         │   Creds     │
└─────────┘         └─────────────┘         └─────────────┘
```

## Configuration

### Service Principal Details

| Setting | Value |
|---------|-------|
| Display Name | `<your-service-principal-name>` |
| Application (Client) ID | `<your-application-id>` |
| Object ID | `<your-object-id>` |
| Directory (Tenant) ID | `<your-tenant-id>` |

### Key Vault Details

| Setting | Value |
|---------|-------|
| Resource Group | `<your-resource-group>` |
| Location | West Europe |
| Vault URI | `https://<your-keyvault>.vault.azure.net/` |
| Secret Name | `<your-secret-name>` |

### Databricks Mirror Connection

| Setting | Value |
|---------|-------|
| Databricks URL | `https://adb-<workspace-id>.<region>.azuredatabricks.net/` |

## Deployment

### Prerequisites

1. **Azure Function App** (Consumption or Premium plan)
2. **Managed Identity** enabled on the Function App
3. **Required Permissions** (see below)

### Required Permissions

#### 1. Microsoft Graph API Permissions

The Function App's Managed Identity needs:

```
Application.ReadWrite.OwnedBy
    OR
Application.ReadWrite.All (more powerful, grants access to all apps)
```

To grant via Azure CLI:

```bash
# Get the Function App's Managed Identity Object ID
FUNCTION_MI_OBJECT_ID=$(az functionapp identity show \
  --name <your-function-app-name> \
  --resource-group <your-resource-group> \
  --query principalId -o tsv)

# Grant Application.ReadWrite.OwnedBy permission
az ad app permission add \
  --id $FUNCTION_MI_OBJECT_ID \
  --api 00000003-0000-0000-c000-000000000000 \
  --api-permissions 18a4783c-866b-4cc7-a460-3d5e5662c884=Role

# Admin consent (requires Global Admin)
az ad app permission admin-consent --id $FUNCTION_MI_OBJECT_ID
```

#### 2. Key Vault Access Policy

Grant the Function App's Managed Identity:
- **Secret Permissions**: Get, Set, List

Via Azure CLI:

```bash
az keyvault set-policy \
  --name <your-keyvault> \
  --object-id $FUNCTION_MI_OBJECT_ID \
  --secret-permissions get set list
```

Or via RBAC:

```bash
az role assignment create \
  --role "Key Vault Secrets Officer" \
  --assignee $FUNCTION_MI_OBJECT_ID \
  --scope /subscriptions/<subscription-id>/resourceGroups/<rg>/providers/Microsoft.KeyVault/vaults/<keyvault-name>
```

#### 3. Fabric API Permissions

The Function App needs to access Fabric APIs:
- **Fabric.ReadWrite.All** (or more specific permissions)

### Deploy the Function

```bash
# Navigate to the function directory
cd KeyRotation-AzureFunction

# Build
dotnet build

# Publish to Azure
func azure functionapp publish <your-function-app-name>
```

### Configure Application Settings

In Azure Portal → Function App → Configuration → Application Settings:

```
ServicePrincipal__ApplicationId = <your-application-id>
ServicePrincipal__ObjectId = <your-object-id>
ServicePrincipal__TenantId = <your-tenant-id>
ServicePrincipal__DisplayName = <your-sp-display-name>

KeyVault__VaultUri = https://<your-keyvault>.vault.azure.net/
KeyVault__SecretName = <your-secret-name>

Fabric__WorkspaceId = <your-workspace-id>
Fabric__ConnectionId = <your-connection-id>
Fabric__DatabricksUrl = https://adb-<workspace-id>.<region>.azuredatabricks.net/

SecretValidityDays = 90
```

## Schedule

The function runs automatically on the **1st of every month at 2:00 AM UTC**.

Cron expression: `0 0 2 1 * *`

| Schedule | Cron Expression |
|----------|-----------------|
| Monthly (1st at 2 AM) | `0 0 2 1 * *` |
| Weekly (Sunday at 3 AM) | `0 0 3 * * 0` |
| Daily at midnight | `0 0 0 * * *` |

## Manual Execution

### Via HTTP Endpoint

```bash
# Get the function key from Azure Portal
FUNCTION_KEY="<your-function-key>"

# Trigger manual rotation
curl -X POST "https://<your-function-app>.azurewebsites.net/api/rotate-key?code=$FUNCTION_KEY"
```

### Via Azure Portal

1. Go to Function App → Functions → RotateServicePrincipalKeyManual
2. Click "Test/Run"
3. Click "Run"

## Monitoring

### Expected Log Output

```
=== Service Principal Key Rotation Started (Scheduled) ===
Timer trigger executed at: 2026-02-01T02:00:00Z
Service Principal: <name> (<application-id>)
Step 1: Creating new client secret...
New secret created, expires: 2026-05-02T02:00:00Z
Step 2: Storing secret in Key Vault...
Secret stored in Key Vault: https://<keyvault>.vault.azure.net//<secret-name>
Step 3: Updating Fabric Mirror Connection...
Fabric Mirror Connection updated successfully
Step 4: Cleaning up old secrets...
Deleted 1 old secret(s)
=== Key Rotation Completed Successfully ===
```

## Known Limitations

### Fabric Mirror Connection Update

The Fabric REST API may not fully support programmatic updates for Mirror Connections. If the automatic update fails, the function will:

1. Create the new secret
2. Store it in Key Vault
3. Log instructions for manual update

In this case, manually update the Fabric Mirror Connection:

1. Go to [Fabric Portal](https://app.fabric.microsoft.com)
2. Navigate to your workspace
3. Find the Databricks Mirror Connection
4. Edit the connection
5. Update Service Principal credentials using the secret from Key Vault

## Security Best Practices

1. **Use Managed Identity** - Never store credentials in code
2. **Limit Permissions** - Use least-privilege principle
3. **Monitor Access** - Enable audit logs on Key Vault
4. **Set Secret Expiration** - Default 90 days, configurable
5. **Retain Recent Secrets** - Keep last 2 for rollback capability

## Project Structure

```
KeyRotation-AzureFunction/
├── KeyRotation.csproj              # Project file
├── Program.cs                       # Host configuration
├── host.json                        # Function host settings
├── local.settings.json.template     # Local settings template
├── README.md                        # This file
└── Functions/
    └── RotateServicePrincipalKeyFunction.cs
```

## References

- [Azure Functions Documentation](https://docs.microsoft.com/azure/azure-functions/)
- [Microsoft Graph API - Applications](https://docs.microsoft.com/graph/api/application-addpassword)
- [Azure Key Vault Secrets Client](https://docs.microsoft.com/dotnet/api/azure.security.keyvault.secrets)
- [Fabric REST API](https://docs.microsoft.com/rest/api/fabric/)

---

*Compiled by Michael Lindner*
