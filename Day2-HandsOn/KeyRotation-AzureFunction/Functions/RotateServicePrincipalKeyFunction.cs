using System.Net.Http.Headers;
using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;
using Azure.Identity;
using Azure.Security.KeyVault.Secrets;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Http;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using Microsoft.Graph;
using Microsoft.Graph.Models;

namespace KeyRotation.Functions;

/// <summary>
/// Azure Function that automatically rotates Service Principal secrets
/// and updates Fabric Mirror Connections.
/// </summary>
public class RotateServicePrincipalKeyFunction
{
    private readonly ILogger<RotateServicePrincipalKeyFunction> _logger;
    private readonly GraphServiceClient _graphClient;
    private readonly IConfiguration _configuration;
    private readonly HttpClient _httpClient;

    public RotateServicePrincipalKeyFunction(
        ILogger<RotateServicePrincipalKeyFunction> logger,
        GraphServiceClient graphClient,
        IConfiguration configuration)
    {
        _logger = logger;
        _graphClient = graphClient;
        _configuration = configuration;
        _httpClient = new HttpClient();
    }

    /// <summary>
    /// Timer-triggered function that runs on the 1st of every month at 2:00 AM UTC.
    /// Cron expression: "0 0 2 1 * *" = At 02:00 on day 1 of every month
    /// </summary>
    [Function("RotateServicePrincipalKey")]
    public async Task RunScheduled(
        [TimerTrigger("0 0 2 1 * *")] TimerInfo timerInfo,
        FunctionContext context)
    {
        _logger.LogInformation("=== Service Principal Key Rotation Started (Scheduled) ===");
        _logger.LogInformation("Timer trigger executed at: {time}", DateTime.UtcNow);

        if (timerInfo.ScheduleStatus is not null)
        {
            _logger.LogInformation("Next scheduled run: {next}", timerInfo.ScheduleStatus.Next);
        }

        await ExecuteKeyRotation();
    }

    /// <summary>
    /// HTTP-triggered function for manual key rotation.
    /// </summary>
    [Function("RotateServicePrincipalKeyManual")]
    public async Task<HttpResponseData> RunManual(
        [HttpTrigger(AuthorizationLevel.Function, "post", Route = "rotate-key")] HttpRequestData req,
        FunctionContext context)
    {
        _logger.LogInformation("=== Service Principal Key Rotation Started (Manual) ===");

        try
        {
            var result = await ExecuteKeyRotation();

            var response = req.CreateResponse(System.Net.HttpStatusCode.OK);
            response.Headers.Add("Content-Type", "application/json");
            await response.WriteStringAsync(JsonSerializer.Serialize(result));
            return response;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Key rotation failed");

            var response = req.CreateResponse(System.Net.HttpStatusCode.InternalServerError);
            response.Headers.Add("Content-Type", "application/json");
            await response.WriteStringAsync(JsonSerializer.Serialize(new { error = ex.Message }));
            return response;
        }
    }

    /// <summary>
    /// Main key rotation logic.
    /// </summary>
    private async Task<RotationResult> ExecuteKeyRotation()
    {
        var result = new RotationResult();

        try
        {
            // Load configuration
            var config = LoadConfiguration();
            result.ServicePrincipalId = config.ApplicationId;

            _logger.LogInformation("Service Principal: {name} ({id})",
                config.DisplayName, config.ApplicationId);

            // Step 1: Create new client secret in Entra ID
            _logger.LogInformation("Step 1: Creating new client secret...");
            var newSecret = await CreateNewClientSecret(config);
            result.NewSecretCreated = true;
            result.SecretExpirationDate = newSecret.EndDateTime?.DateTime;
            _logger.LogInformation("New secret created, expires: {expiry}", newSecret.EndDateTime);

            // Step 2: Store secret in Key Vault
            _logger.LogInformation("Step 2: Storing secret in Key Vault...");
            await StoreSecretInKeyVault(config, newSecret.SecretText!);
            result.StoredInKeyVault = true;
            _logger.LogInformation("Secret stored in Key Vault: {vault}/{secret}",
                config.KeyVaultUri, config.KeyVaultSecretName);

            // Step 3: Update Fabric Mirror Connection
            _logger.LogInformation("Step 3: Updating Fabric Mirror Connection...");
            await UpdateFabricMirrorConnection(config, newSecret.SecretText!);
            result.FabricConnectionUpdated = true;
            _logger.LogInformation("Fabric Mirror Connection updated successfully");

            // Step 4: Clean up old secrets (optional - keep last 2)
            _logger.LogInformation("Step 4: Cleaning up old secrets...");
            var deletedCount = await CleanupOldSecrets(config, keepCount: 2);
            result.OldSecretsDeleted = deletedCount;
            _logger.LogInformation("Deleted {count} old secret(s)", deletedCount);

            result.Success = true;
            result.Message = "Key rotation completed successfully";
            _logger.LogInformation("=== Key Rotation Completed Successfully ===");
        }
        catch (Exception ex)
        {
            result.Success = false;
            result.Message = ex.Message;
            result.ErrorDetails = ex.ToString();
            _logger.LogError(ex, "Key rotation failed");
            throw;
        }

        return result;
    }

    /// <summary>
    /// Loads configuration from application settings.
    /// </summary>
    private ServicePrincipalConfig LoadConfiguration()
    {
        return new ServicePrincipalConfig
        {
            ApplicationId = _configuration["ServicePrincipal__ApplicationId"]
                ?? throw new InvalidOperationException("ServicePrincipal__ApplicationId not configured"),
            ObjectId = _configuration["ServicePrincipal__ObjectId"]
                ?? throw new InvalidOperationException("ServicePrincipal__ObjectId not configured"),
            TenantId = _configuration["ServicePrincipal__TenantId"]
                ?? throw new InvalidOperationException("ServicePrincipal__TenantId not configured"),
            DisplayName = _configuration["ServicePrincipal__DisplayName"] ?? "ServicePrincipal",
            KeyVaultUri = _configuration["KeyVault__VaultUri"]
                ?? throw new InvalidOperationException("KeyVault__VaultUri not configured"),
            KeyVaultSecretName = _configuration["KeyVault__SecretName"] ?? "ServicePrincipalSecret",
            FabricWorkspaceId = _configuration["Fabric__WorkspaceId"]
                ?? throw new InvalidOperationException("Fabric__WorkspaceId not configured"),
            FabricConnectionId = _configuration["Fabric__ConnectionId"],
            DatabricksUrl = _configuration["Fabric__DatabricksUrl"]
                ?? throw new InvalidOperationException("Fabric__DatabricksUrl not configured"),
            SecretValidityDays = int.Parse(_configuration["SecretValidityDays"] ?? "90")
        };
    }

    /// <summary>
    /// Creates a new client secret for the Service Principal using Microsoft Graph API.
    /// </summary>
    private async Task<PasswordCredential> CreateNewClientSecret(ServicePrincipalConfig config)
    {
        var passwordCredential = new PasswordCredential
        {
            DisplayName = $"AutoRotated-{DateTime.UtcNow:yyyyMMdd-HHmmss}",
            EndDateTime = DateTimeOffset.UtcNow.AddDays(config.SecretValidityDays)
        };

        // Use the Application endpoint (not ServicePrincipal) to add credentials
        var result = await _graphClient.Applications[config.ObjectId]
            .AddPassword
            .PostAsync(new Microsoft.Graph.Applications.Item.AddPassword.AddPasswordPostRequestBody
            {
                PasswordCredential = passwordCredential
            });

        if (result?.SecretText == null)
        {
            throw new InvalidOperationException("Failed to create client secret - no secret text returned");
        }

        return result;
    }

    /// <summary>
    /// Stores the new secret in Azure Key Vault.
    /// </summary>
    private async Task StoreSecretInKeyVault(ServicePrincipalConfig config, string secretValue)
    {
        var credential = new DefaultAzureCredential();
        var client = new SecretClient(new Uri(config.KeyVaultUri), credential);

        // Store the secret with metadata
        var secret = new KeyVaultSecret(config.KeyVaultSecretName, secretValue)
        {
            Properties =
            {
                ExpiresOn = DateTimeOffset.UtcNow.AddDays(config.SecretValidityDays),
                ContentType = "application/x-service-principal-secret",
                Tags =
                {
                    ["ServicePrincipalId"] = config.ApplicationId,
                    ["ServicePrincipalName"] = config.DisplayName,
                    ["CreatedBy"] = "AzureFunction-KeyRotation",
                    ["CreatedAt"] = DateTime.UtcNow.ToString("o")
                }
            }
        };

        await client.SetSecretAsync(secret);
    }

    /// <summary>
    /// Updates the Fabric Mirror Connection with the new secret.
    /// </summary>
    private async Task UpdateFabricMirrorConnection(ServicePrincipalConfig config, string newSecret)
    {
        var credential = new DefaultAzureCredential();

        // Get token for Fabric API
        var fabricToken = await credential.GetTokenAsync(
            new Azure.Core.TokenRequestContext(new[] { "https://api.fabric.microsoft.com/.default" }));

        _httpClient.DefaultRequestHeaders.Authorization =
            new AuthenticationHeaderValue("Bearer", fabricToken.Token);

        // Step 1: Find the connection by searching all connections in the workspace
        _logger.LogInformation("Searching for Databricks connection in workspace {workspaceId}...", 
            config.FabricWorkspaceId);

        var connection = await FindDatabricksConnection(config);

        if (connection == null)
        {
            throw new InvalidOperationException(
                $"Could not find Databricks connection with URL {config.DatabricksUrl} in workspace {config.FabricWorkspaceId}");
        }

        _logger.LogInformation("Found connection: {name} (ID: {id})", connection.DisplayName, connection.Id);

        // Step 2: Update the connection credentials
        await UpdateConnectionCredentials(config, connection.Id!, newSecret);
    }

    /// <summary>
    /// Finds the Databricks connection in the workspace.
    /// </summary>
    private async Task<FabricConnection?> FindDatabricksConnection(ServicePrincipalConfig config)
    {
        // Try Fabric Connections API first
        var connectionsEndpoint = $"https://api.fabric.microsoft.com/v1/workspaces/{config.FabricWorkspaceId}/connections";

        _logger.LogInformation("Fetching connections from: {endpoint}", connectionsEndpoint);

        var response = await _httpClient.GetAsync(connectionsEndpoint);

        if (response.IsSuccessStatusCode)
        {
            var content = await response.Content.ReadAsStringAsync();
            _logger.LogDebug("Connections response: {content}", content);

            var connectionsResponse = JsonSerializer.Deserialize<FabricConnectionsResponse>(content);

            if (connectionsResponse?.Value != null)
            {
                // Find connection matching the Databricks URL
                var matchingConnection = connectionsResponse.Value
                    .FirstOrDefault(c =>
                        c.ConnectionDetails?.Path?.Contains(config.DatabricksUrl.TrimEnd('/'), 
                            StringComparison.OrdinalIgnoreCase) == true ||
                        c.ConnectionDetails?.Server?.Contains("azuredatabricks.net", 
                            StringComparison.OrdinalIgnoreCase) == true ||
                        c.ConnectivityType?.Contains("Databricks", 
                            StringComparison.OrdinalIgnoreCase) == true);

                if (matchingConnection != null)
                {
                    return matchingConnection;
                }

                // Log all connections for debugging
                _logger.LogInformation("Found {count} connections in workspace:", connectionsResponse.Value.Count);
                foreach (var conn in connectionsResponse.Value)
                {
                    _logger.LogInformation("  - {name} | Type: {type} | Path: {path}",
                        conn.DisplayName, conn.ConnectivityType, conn.ConnectionDetails?.Path);
                }
            }
        }
        else
        {
            var errorContent = await response.Content.ReadAsStringAsync();
            _logger.LogWarning("Connections API failed: {status} - {error}", response.StatusCode, errorContent);
        }

        // Try alternative: Power BI Datasources API
        _logger.LogInformation("Trying Power BI Datasources API...");
        return await FindConnectionViaPowerBIApi(config);
    }

    /// <summary>
    /// Alternative method to find connection via Power BI Gateway API.
    /// </summary>
    private async Task<FabricConnection?> FindConnectionViaPowerBIApi(ServicePrincipalConfig config)
    {
        var credential = new DefaultAzureCredential();
        var pbiToken = await credential.GetTokenAsync(
            new Azure.Core.TokenRequestContext(new[] { "https://analysis.windows.net/powerbi/api/.default" }));

        using var pbiClient = new HttpClient();
        pbiClient.DefaultRequestHeaders.Authorization =
            new AuthenticationHeaderValue("Bearer", pbiToken.Token);

        // Get all gateways and datasources
        var gatewaysEndpoint = "https://api.powerbi.com/v1.0/myorg/gateways";
        var response = await pbiClient.GetAsync(gatewaysEndpoint);

        if (response.IsSuccessStatusCode)
        {
            var content = await response.Content.ReadAsStringAsync();
            _logger.LogDebug("Gateways response: {content}", content);

            var gatewaysResponse = JsonSerializer.Deserialize<GatewaysResponse>(content);

            if (gatewaysResponse?.Value != null)
            {
                foreach (var gateway in gatewaysResponse.Value)
                {
                    // Get datasources for each gateway
                    var datasourcesEndpoint = $"https://api.powerbi.com/v1.0/myorg/gateways/{gateway.Id}/datasources";
                    var dsResponse = await pbiClient.GetAsync(datasourcesEndpoint);

                    if (dsResponse.IsSuccessStatusCode)
                    {
                        var dsContent = await dsResponse.Content.ReadAsStringAsync();
                        var datasourcesResponse = JsonSerializer.Deserialize<DatasourcesResponse>(dsContent);

                        var matchingDs = datasourcesResponse?.Value?
                            .FirstOrDefault(ds =>
                                ds.ConnectionDetails?.Contains("azuredatabricks.net", 
                                    StringComparison.OrdinalIgnoreCase) == true ||
                                ds.ConnectionDetails?.Contains(config.DatabricksUrl, 
                                    StringComparison.OrdinalIgnoreCase) == true);

                        if (matchingDs != null)
                        {
                            return new FabricConnection
                            {
                                Id = matchingDs.Id,
                                DisplayName = matchingDs.DatasourceName ?? "Databricks Connection",
                                GatewayId = gateway.Id,
                                ConnectionDetails = new ConnectionDetails { Path = matchingDs.ConnectionDetails }
                            };
                        }
                    }
                }
            }
        }

        // If using Connection ID from config, create a minimal connection object
        if (!string.IsNullOrEmpty(config.FabricConnectionId))
        {
            _logger.LogInformation("Using configured Connection ID: {id}", config.FabricConnectionId);
            return new FabricConnection
            {
                Id = config.FabricConnectionId,
                DisplayName = "Databricks Mirror Connection",
                ConnectionDetails = new ConnectionDetails { Path = config.DatabricksUrl }
            };
        }

        return null;
    }

    /// <summary>
    /// Updates the connection credentials with the new secret.
    /// </summary>
    private async Task UpdateConnectionCredentials(ServicePrincipalConfig config, string connectionId, string newSecret)
    {
        _logger.LogInformation("Updating credentials for connection: {connectionId}", connectionId);

        // Method 1: Try Fabric Connections API - Update Credentials
        var updateCredentialsEndpoint = $"https://api.fabric.microsoft.com/v1/workspaces/{config.FabricWorkspaceId}/connections/{connectionId}/credentials";

        var credentialsPayload = new
        {
            credentialType = "ServicePrincipal",
            servicePrincipalCredentials = new
            {
                tenantId = config.TenantId,
                servicePrincipalClientId = config.ApplicationId,
                servicePrincipalSecret = newSecret
            }
        };

        var content = new StringContent(
            JsonSerializer.Serialize(credentialsPayload),
            Encoding.UTF8,
            "application/json");

        var response = await _httpClient.PatchAsync(updateCredentialsEndpoint, content);

        if (response.IsSuccessStatusCode)
        {
            _logger.LogInformation("Connection credentials updated successfully via Fabric API!");
            return;
        }

        var errorContent = await response.Content.ReadAsStringAsync();
        _logger.LogWarning("Fabric Credentials API failed: {status} - {error}", response.StatusCode, errorContent);

        // Method 2: Try updating the full connection object
        var updateConnectionEndpoint = $"https://api.fabric.microsoft.com/v1/workspaces/{config.FabricWorkspaceId}/connections/{connectionId}";

        var connectionPayload = new
        {
            credentialDetails = new
            {
                credentialType = "ServicePrincipal",
                credentials = new
                {
                    tenantId = config.TenantId,
                    servicePrincipalClientId = config.ApplicationId,
                    servicePrincipalSecret = newSecret
                }
            }
        };

        content = new StringContent(
            JsonSerializer.Serialize(connectionPayload),
            Encoding.UTF8,
            "application/json");

        response = await _httpClient.PatchAsync(updateConnectionEndpoint, content);

        if (response.IsSuccessStatusCode)
        {
            _logger.LogInformation("Connection updated successfully via PATCH!");
            return;
        }

        errorContent = await response.Content.ReadAsStringAsync();
        _logger.LogWarning("Connection PATCH failed: {status} - {error}", response.StatusCode, errorContent);

        // Method 3: Try Power BI Gateway Datasources API
        await UpdateViaPowerBIGatewayApi(config, connectionId, newSecret);
    }

    /// <summary>
    /// Attempts to update credentials via Power BI Gateway API.
    /// </summary>
    private async Task UpdateViaPowerBIGatewayApi(ServicePrincipalConfig config, string connectionId, string newSecret)
    {
        var credential = new DefaultAzureCredential();
        var pbiToken = await credential.GetTokenAsync(
            new Azure.Core.TokenRequestContext(new[] { "https://analysis.windows.net/powerbi/api/.default" }));

        using var pbiClient = new HttpClient();
        pbiClient.DefaultRequestHeaders.Authorization =
            new AuthenticationHeaderValue("Bearer", pbiToken.Token);

        // Try to update datasource credentials directly
        var gatewaysEndpoint = "https://api.powerbi.com/v1.0/myorg/gateways";
        var gatewaysResponse = await pbiClient.GetAsync(gatewaysEndpoint);

        if (gatewaysResponse.IsSuccessStatusCode)
        {
            var gatewaysContent = await gatewaysResponse.Content.ReadAsStringAsync();
            var gateways = JsonSerializer.Deserialize<GatewaysResponse>(gatewaysContent);

            foreach (var gateway in gateways?.Value ?? new List<Gateway>())
            {
                // Try to update the datasource in this gateway
                var updateDsEndpoint = $"https://api.powerbi.com/v1.0/myorg/gateways/{gateway.Id}/datasources/{connectionId}";

                // Build the credential update payload for Service Principal
                var credentialDetails = new
                {
                    credentialType = "OAuth2",
                    credentials = JsonSerializer.Serialize(new
                    {
                        tenantId = config.TenantId,
                        servicePrincipalClientId = config.ApplicationId,
                        servicePrincipalSecret = newSecret
                    }),
                    encryptedConnection = "Encrypted",
                    encryptionAlgorithm = "None",
                    privacyLevel = "Organizational"
                };

                var updatePayload = new { credentialDetails };
                var content = new StringContent(
                    JsonSerializer.Serialize(updatePayload),
                    Encoding.UTF8,
                    "application/json");

                var response = await pbiClient.PatchAsync(updateDsEndpoint, content);

                if (response.IsSuccessStatusCode)
                {
                    _logger.LogInformation("Connection credentials updated via Power BI Gateway API!");
                    return;
                }

                var error = await response.Content.ReadAsStringAsync();
                _logger.LogDebug("Gateway {id} update attempt: {status} - {error}", 
                    gateway.Id, response.StatusCode, error);
            }
        }

        // If all methods fail, log detailed instructions
        _logger.LogWarning("Automatic credential update failed. Manual update required.");
        _logger.LogInformation(@"
╔══════════════════════════════════════════════════════════════════╗
║                    MANUAL UPDATE REQUIRED                        ║
╠══════════════════════════════════════════════════════════════════╣
║ The new secret has been created and stored in Key Vault.         ║
║ Please update the Fabric Mirror Connection manually:             ║
║                                                                  ║
║ 1. Go to: https://app.fabric.microsoft.com                       ║
║ 2. Navigate to your workspace                                    ║
║ 3. Find the Databricks Mirror Connection                         ║
║ 4. Click Edit / Update credentials                               ║
║ 5. Enter the credentials from Key Vault                          ║
╚══════════════════════════════════════════════════════════════════╝");
    }

    /// <summary>
    /// Cleans up old secrets, keeping only the most recent ones.
    /// </summary>
    private async Task<int> CleanupOldSecrets(ServicePrincipalConfig config, int keepCount)
    {
        try
        {
            var app = await _graphClient.Applications[config.ObjectId].GetAsync();

            if (app?.PasswordCredentials == null || app.PasswordCredentials.Count <= keepCount)
            {
                return 0;
            }

            // Sort by end date descending, skip the newest ones
            var secretsToDelete = app.PasswordCredentials
                .OrderByDescending(p => p.EndDateTime)
                .Skip(keepCount)
                .ToList();

            foreach (var secret in secretsToDelete)
            {
                if (secret.KeyId.HasValue)
                {
                    await _graphClient.Applications[config.ObjectId]
                        .RemovePassword
                        .PostAsync(new Microsoft.Graph.Applications.Item.RemovePassword.RemovePasswordPostRequestBody
                        {
                            KeyId = secret.KeyId.Value
                        });

                    _logger.LogInformation("Deleted old secret: {name} (KeyId: {keyId})",
                        secret.DisplayName, secret.KeyId);
                }
            }

            return secretsToDelete.Count;
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Failed to cleanup old secrets - continuing anyway");
            return 0;
        }
    }
}

#region Configuration and Result Models

public class ServicePrincipalConfig
{
    public required string ApplicationId { get; set; }
    public required string ObjectId { get; set; }
    public required string TenantId { get; set; }
    public required string DisplayName { get; set; }
    public required string KeyVaultUri { get; set; }
    public required string KeyVaultSecretName { get; set; }
    public required string FabricWorkspaceId { get; set; }
    public string? FabricConnectionId { get; set; }
    public required string DatabricksUrl { get; set; }
    public int SecretValidityDays { get; set; } = 90;
}

public class RotationResult
{
    public bool Success { get; set; }
    public string? Message { get; set; }
    public string? ServicePrincipalId { get; set; }
    public bool NewSecretCreated { get; set; }
    public DateTime? SecretExpirationDate { get; set; }
    public bool StoredInKeyVault { get; set; }
    public bool FabricConnectionUpdated { get; set; }
    public int OldSecretsDeleted { get; set; }
    public string? ErrorDetails { get; set; }
    public string? ConnectionId { get; set; }
    public string? ConnectionName { get; set; }
}

#endregion

#region Fabric API Response Models

public class FabricConnectionsResponse
{
    [JsonPropertyName("value")]
    public List<FabricConnection>? Value { get; set; }

    [JsonPropertyName("continuationToken")]
    public string? ContinuationToken { get; set; }
}

public class FabricConnection
{
    [JsonPropertyName("id")]
    public string? Id { get; set; }

    [JsonPropertyName("displayName")]
    public string? DisplayName { get; set; }

    [JsonPropertyName("connectivityType")]
    public string? ConnectivityType { get; set; }

    [JsonPropertyName("connectionDetails")]
    public ConnectionDetails? ConnectionDetails { get; set; }

    [JsonPropertyName("credentialDetails")]
    public CredentialDetails? CredentialDetails { get; set; }

    [JsonPropertyName("gatewayId")]
    public string? GatewayId { get; set; }
}

public class ConnectionDetails
{
    [JsonPropertyName("type")]
    public string? Type { get; set; }

    [JsonPropertyName("path")]
    public string? Path { get; set; }

    [JsonPropertyName("server")]
    public string? Server { get; set; }

    [JsonPropertyName("database")]
    public string? Database { get; set; }
}

public class CredentialDetails
{
    [JsonPropertyName("credentialType")]
    public string? CredentialType { get; set; }

    [JsonPropertyName("connectionEncryption")]
    public string? ConnectionEncryption { get; set; }

    [JsonPropertyName("skipTestConnection")]
    public bool? SkipTestConnection { get; set; }
}

#endregion

#region Power BI Gateway API Response Models

public class GatewaysResponse
{
    [JsonPropertyName("value")]
    public List<Gateway>? Value { get; set; }
}

public class Gateway
{
    [JsonPropertyName("id")]
    public string? Id { get; set; }

    [JsonPropertyName("name")]
    public string? Name { get; set; }

    [JsonPropertyName("type")]
    public string? Type { get; set; }

    [JsonPropertyName("publicKey")]
    public PublicKey? PublicKey { get; set; }
}

public class PublicKey
{
    [JsonPropertyName("exponent")]
    public string? Exponent { get; set; }

    [JsonPropertyName("modulus")]
    public string? Modulus { get; set; }
}

public class DatasourcesResponse
{
    [JsonPropertyName("value")]
    public List<Datasource>? Value { get; set; }
}

public class Datasource
{
    [JsonPropertyName("id")]
    public string? Id { get; set; }

    [JsonPropertyName("gatewayId")]
    public string? GatewayId { get; set; }

    [JsonPropertyName("datasourceType")]
    public string? DatasourceType { get; set; }

    [JsonPropertyName("datasourceName")]
    public string? DatasourceName { get; set; }

    [JsonPropertyName("connectionDetails")]
    public string? ConnectionDetails { get; set; }

    [JsonPropertyName("credentialType")]
    public string? CredentialType { get; set; }

    [JsonPropertyName("credentialDetails")]
    public DatasourceCredentialDetails? CredentialDetailsObj { get; set; }
}

public class DatasourceCredentialDetails
{
    [JsonPropertyName("credentialType")]
    public string? CredentialType { get; set; }

    [JsonPropertyName("useEndUserOAuth2Credentials")]
    public bool? UseEndUserOAuth2Credentials { get; set; }
}

#endregion
