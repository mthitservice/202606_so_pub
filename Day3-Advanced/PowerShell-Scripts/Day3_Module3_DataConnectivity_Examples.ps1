# =============================================================================
# Day 3 - Module 3 - Data Connectivity Examples
# =============================================================================
# Power Query M scripts and connection string examples for various data sources
# These are typically used in Power BI Desktop's Power Query Editor

Write-Host "=== Data Connectivity Reference Guide ===" -ForegroundColor Cyan

# -----------------------------------------------------------------------------
# Exercise 3.1: Azure SQL Database Connection
# -----------------------------------------------------------------------------
Write-Host "`n=== Azure SQL Database Connection ===" -ForegroundColor Yellow

$azureSqlExample = @'
// Power Query M - Azure SQL Database Connection

let
    // Connection parameters
    Server = "yourserver.database.windows.net",
    Database = "AdventureWorksLT",
    
    // Connect to database
    Source = Sql.Database(Server, Database, [
        Query = "SELECT * FROM SalesLT.Customer",
        CommandTimeout = #duration(0, 0, 10, 0)  // 10 minute timeout
    ])
in
    Source

// Alternative: Connect to entire database (browse tables)
let
    Source = Sql.Database("yourserver.database.windows.net", "AdventureWorksLT"),
    SalesLT_Customer = Source{[Schema="SalesLT",Item="Customer"]}[Data]
in
    SalesLT_Customer
'@

Write-Host $azureSqlExample

# Connection string for reference
$azureSqlConnString = @"

Connection String (for reference):
Server=yourserver.database.windows.net;Database=AdventureWorksLT;Authentication=Active Directory Integrated;Encrypt=True;

Or with SQL Auth:
Server=yourserver.database.windows.net;Database=AdventureWorksLT;User ID=username;Password=password;Encrypt=True;
"@
Write-Host $azureSqlConnString -ForegroundColor Gray

# -----------------------------------------------------------------------------
# Exercise 3.2: SharePoint Online List Connection
# -----------------------------------------------------------------------------
Write-Host "`n=== SharePoint Online List Connection ===" -ForegroundColor Yellow

$sharePointExample = @'
// Power Query M - SharePoint Online List

let
    // SharePoint site URL
    SiteUrl = "https://yourtenant.sharepoint.com/sites/yoursite",
    
    // Get all lists
    Source = SharePoint.Tables(SiteUrl, [ApiVersion = 15]),
    
    // Select specific list
    SalesList = Source{[Title="SalesList"]}[Items],
    
    // Remove system columns
    CleanedData = Table.RemoveColumns(SalesList, {
        "ContentTypeId", "Modified", "Created", "Author", 
        "Editor", "_UIVersionString", "Attachments", 
        "GUID", "ServerRedirectedEmbedUri", "Id", 
        "ContentType", "FileSystemObjectType", "OData__ColorTag"
    })
in
    CleanedData

// Alternative: SharePoint Files (Excel/CSV from document library)
let
    Source = SharePoint.Files("https://yourtenant.sharepoint.com/sites/yoursite", [ApiVersion = 15]),
    FilteredFiles = Table.SelectRows(Source, each Text.EndsWith([Name], ".xlsx")),
    FirstFile = FilteredFiles{0}[Content],
    ImportedExcel = Excel.Workbook(FirstFile, null, true),
    Sheet1 = ImportedExcel{[Item="Sheet1",Kind="Sheet"]}[Data]
in
    Sheet1
'@

Write-Host $sharePointExample

# -----------------------------------------------------------------------------
# Exercise 3.3: On-Premises File Server Connection
# -----------------------------------------------------------------------------
Write-Host "`n=== File Server Connection (Requires Gateway) ===" -ForegroundColor Yellow

$fileServerExample = @'
// Power Query M - Network File Share (requires On-Premises Data Gateway)

// Excel file from network share
let
    Source = Excel.Workbook(
        File.Contents("\\FileServer01\Finance\Reports\Monthly.xlsx"), 
        null, 
        true
    ),
    Sheet1 = Source{[Item="Sheet1",Kind="Sheet"]}[Data],
    PromotedHeaders = Table.PromoteHeaders(Sheet1, [PromoteAllScalars=true])
in
    PromotedHeaders

// CSV file from network share
let
    Source = Csv.Document(
        File.Contents("\\FileServer01\Data\Sales.csv"),
        [Delimiter=",", Encoding=65001, QuoteStyle=QuoteStyle.None]
    ),
    PromotedHeaders = Table.PromoteHeaders(Source, [PromoteAllScalars=true])
in
    PromotedHeaders

// All Excel files in a folder
let
    Source = Folder.Files("\\FileServer01\Finance\MonthlyReports"),
    FilteredFiles = Table.SelectRows(Source, each Text.EndsWith([Name], ".xlsx")),
    AddedContent = Table.AddColumn(FilteredFiles, "Data", each Excel.Workbook([Content])),
    ExpandedData = Table.ExpandTableColumn(AddedContent, "Data", {"Name", "Data"}, {"SheetName", "SheetData"})
in
    ExpandedData
'@

Write-Host $fileServerExample

# -----------------------------------------------------------------------------
# Exercise 3.4: Composite Model - Mixed Storage Modes
# -----------------------------------------------------------------------------
Write-Host "`n=== Composite Model Configuration ===" -ForegroundColor Yellow

$compositeExample = @'
// Composite Model Strategy

IMPORT MODE (for dimension tables):
- DimDate        → Import (small, frequently filtered)
- DimProduct     → Import (small, frequently joined)
- DimCustomer    → Import (medium, stable data)
- DimGeography   → Import (very small)

DIRECTQUERY MODE (for fact tables):
- FactSales      → DirectQuery (large, needs live data)
- FactInventory  → DirectQuery (large, real-time requirements)

DUAL MODE (hybrid):
- Tables that need both Import (for dimensions) and DirectQuery (for facts)

// Setting Storage Mode in Power BI Desktop:
1. Go to Model view
2. Select table in diagram
3. In Properties pane, change "Storage mode"
   - Import: Data cached in model
   - DirectQuery: Queries sent to source
   - Dual: Both (for aggregations)

// Aggregation Table Pattern:
- FactSales_Agg (Import) - Aggregated to Month/Product level
- FactSales (DirectQuery) - Detail level

// Power Query M for Aggregation Table:
let
    Source = Sql.Database("server", "db"),
    FactSales = Source{[Schema="dbo",Item="FactSales"]}[Data],
    Aggregated = Table.Group(FactSales, {"DateKey", "ProductKey"}, {
        {"SalesAmount", each List.Sum([SalesAmount]), type number},
        {"Quantity", each List.Sum([Quantity]), type number}
    })
in
    Aggregated
'@

Write-Host $compositeExample

# -----------------------------------------------------------------------------
# Privacy Level Settings Reference
# -----------------------------------------------------------------------------
Write-Host "`n=== Privacy Level Settings ===" -ForegroundColor Yellow

Write-Host @"

Privacy Levels determine how data sources can be combined:

PUBLIC:
- Data can be combined with any source
- Use for: Public APIs, open data

ORGANIZATIONAL:
- Can combine with other Organizational sources
- Use for: Internal databases, SharePoint, corporate systems

PRIVATE:
- Cannot be combined with other sources
- Use for: Highly sensitive data, personal data

Setting Privacy Levels:
1. Power Query Editor > File > Options > Data Source Settings
2. Select data source > Edit Permissions > Privacy Level

Tip: In Power BI Desktop, go to File > Options > Current File > Privacy
     and set "Ignore privacy levels" for development (not recommended for production)
"@

# -----------------------------------------------------------------------------
# Summary: Data Source Configuration Checklist
# -----------------------------------------------------------------------------
Write-Host "`n=== Data Source Configuration Checklist ===" -ForegroundColor Cyan

Write-Host @"

Before Publishing:

[ ] Test connection in Power BI Desktop
[ ] Set appropriate privacy levels
[ ] Configure incremental refresh (if applicable)
[ ] Document connection details
[ ] Verify gateway requirements:
    - Cloud sources (Azure, SharePoint Online): No gateway needed
    - On-premises sources: Gateway required

After Publishing:

[ ] Configure gateway binding (if on-premises)
[ ] Set up credentials in Power BI Service
[ ] Configure refresh schedule
[ ] Test manual refresh
[ ] Verify data appears correctly
"@
