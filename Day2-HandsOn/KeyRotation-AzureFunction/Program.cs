using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Azure.Identity;
using Microsoft.Graph;

var host = new HostBuilder()
    .ConfigureFunctionsWorkerDefaults()
    .ConfigureServices(services =>
    {
        // Uncomment to enable Application Insights
        // services.AddApplicationInsightsTelemetryWorkerService();
        // services.ConfigureFunctionsApplicationInsights();
        
        services.AddSingleton(sp =>
        {
            var credential = new DefaultAzureCredential();
            return new GraphServiceClient(credential, new[] { "https://graph.microsoft.com/.default" });
        });
    });

host.Build().Run();
