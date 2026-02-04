# Day 2: KQL and Workspace Monitoring

This document covers KQL (Kusto Query Language) fundamentals and workspace monitoring for Microsoft Fabric.

---

## KQL Fundamentals

### Basic KQL Syntax

KQL follows a pipe-based syntax:

```kusto
TableName
| where Condition
| project Column1, Column2
| summarize Count = count() by GroupColumn
| order by Count desc
| take 10
```

### SQL to KQL Translation Guide

| SQL | KQL |
|-----|-----|
| `SELECT *` | `TableName` |
| `SELECT col1, col2` | `| project col1, col2` |
| `WHERE condition` | `| where condition` |
| `GROUP BY col` | `| summarize by col` |
| `ORDER BY col DESC` | `| order by col desc` |
| `TOP 10` | `| take 10` or `| top 10 by col` |
| `COUNT(*)` | `count()` |
| `AVG(col)` | `avg(col)` |
| `DISTINCT col` | `| distinct col` |
| `LIKE '%text%'` | `| where col contains "text"` |
| `DATEADD(day, -7, GETDATE())` | `ago(7d)` |

### Essential KQL Operators

```kusto
// Time-based filtering
| where timestamp > ago(7d)
| where timestamp between (ago(7d) .. now())

// String operations
| where QueryText contains "CALCULATE"
| where ExecutingUser startswith "admin"
| where ItemName matches regex "Sales.*"

// Numeric comparisons
| where DurationMs > 5000
| where RowCount between (1000 .. 10000)

// Null handling
| where isnotempty(ErrorMessage)
| where isnull(EndTime)

// Multiple conditions
| where DurationMs > 3000 and Status == "Success"
| where Application in ("Power BI Desktop", "Excel")
```

### Time Binning with bin()

```kusto
// Group by hour
| summarize QueryCount = count() by bin(timestamp, 1h)

// Group by 15-minute intervals
| summarize AvgDuration = avg(DurationMs) by bin(timestamp, 15m)

// Group by day
| summarize TotalQueries = count() by bin(timestamp, 1d)
```

---

## Advanced KQL Queries for Semantic Model Analysis

### Performance Overview Dashboard Query

```kusto
queries
| where timestamp > ago(24h)
| summarize
    TotalQueries = count(),
    SuccessfulQueries = countif(Status == "Success"),
    FailedQueries = countif(Status != "Success"),
    AvgDurationMs = avg(DurationMs),
    P50Duration = percentile(DurationMs, 50),
    P90Duration = percentile(DurationMs, 90),
    P99Duration = percentile(DurationMs, 99),
    MaxDuration = max(DurationMs),
    TotalCpuMs = sum(CpuTimeMs),
    UniqueUsers = dcount(ExecutingUser),
    TotalRowsReturned = sum(RowCount)
| extend
    SuccessRate = round(100.0 * SuccessfulQueries / TotalQueries, 2),
    AvgDurationSeconds = round(AvgDurationMs / 1000.0, 2)
```

### Slow Query Detection

```kusto
queries
| where timestamp > ago(7d)
| where DurationMs > 3000
| summarize
    ExecutionCount = count(),
    AvgDuration = avg(DurationMs),
    MaxDuration = max(DurationMs),
    MinDuration = min(DurationMs),
    AffectedUsers = dcount(ExecutingUser)
    by QueryTextHash = hash(QueryText),
       QueryPreview = substring(QueryText, 0, 200)
| where ExecutionCount > 5
| order by AvgDuration desc
| take 20
```

### Storage Engine vs Formula Engine Analysis

```kusto
queries
| where timestamp > ago(7d)
| where DurationMs > 1000
| extend
    SEPercentage = round(100.0 * StorageEngineDurationMs / DurationMs, 1),
    FEPercentage = round(100.0 * FormulaEngineDurationMs / DurationMs, 1)
| summarize
    AvgSEPercent = avg(SEPercentage),
    AvgFEPercent = avg(FEPercentage),
    Count = count()
    by ItemName
| where AvgFEPercent > 50
| order by AvgFEPercent desc
```

### User Activity Patterns

```kusto
queries
| where timestamp > ago(30d)
| extend
    HourOfDay = datetime_part("hour", timestamp),
    DayOfWeek = dayofweek(timestamp),
    DayName = case(
        dayofweek(timestamp) == 0d, "Sunday",
        dayofweek(timestamp) == 1d, "Monday",
        dayofweek(timestamp) == 2d, "Tuesday",
        dayofweek(timestamp) == 3d, "Wednesday",
        dayofweek(timestamp) == 4d, "Thursday",
        dayofweek(timestamp) == 5d, "Friday",
        "Saturday")
| summarize
    QueryCount = count(),
    UniqueUsers = dcount(ExecutingUser),
    AvgDuration = avg(DurationMs)
    by DayName, HourOfDay
| order by DayName asc, HourOfDay asc
```

### Semantic Model Health Score

```kusto
queries
| where timestamp > ago(7d)
| summarize
    TotalQueries = count(),
    FailedQueries = countif(Status != "Success"),
    SlowQueries = countif(DurationMs > 5000),
    VerySlowQueries = countif(DurationMs > 10000),
    AvgDuration = avg(DurationMs),
    P90Duration = percentile(DurationMs, 90)
    by ItemId, ItemName
| extend
    FailureRate = round(100.0 * FailedQueries / TotalQueries, 2),
    SlowQueryRate = round(100.0 * SlowQueries / TotalQueries, 2),
    HealthScore = round(100
        - (FailureRate * 2)
        - (SlowQueryRate * 0.5)
        - case(AvgDuration > 5000, 20,
               AvgDuration > 3000, 10,
               AvgDuration > 1000, 5,
               0), 1)
| project ItemName, TotalQueries, FailureRate, SlowQueryRate, AvgDuration, HealthScore
| order by HealthScore asc
```

---

## Workspace Monitoring

### Enabling Workspace Monitoring

1. Open a Premium/Fabric workspace
2. Click Settings (gear icon)
3. Navigate to "Workspace monitoring"
4. Toggle "Enable workspace monitoring"
5. Wait 5-10 minutes for lakehouse creation

**What Gets Created:**

```
Your Workspace
├── [Your existing items...]
└── Monitoring (Lakehouse)
    ├── Tables
    │   ├── queries
    │   ├── operations
    │   └── datasources
    ├── SQL Analytics Endpoint
    └── Default semantic model
```

### Key Monitoring Tables

| Table | Purpose |
|-------|---------|
| `queries` | DAX query execution logs |
| `operations` | Refresh and processing operations |
| `datasources` | Data source connection information |

### Data Retention

Monitoring data is retained for **30 days** by default. For longer retention:
1. Create a Data Pipeline
2. Copy data to another Lakehouse
3. Schedule daily/weekly archival

---

## SQL Alternatives for Non-KQL Users

### Query Log Schema

```sql
SELECT
    timestamp,
    WorkspaceName,
    ItemName,
    ExecutingUser,
    QueryText,
    DurationMs,
    CpuTimeMs,
    StorageEngineDurationMs,
    FormulaEngineDurationMs,
    RowCount,
    Status,
    Application
FROM queries
WHERE timestamp > DATEADD(day, -7, GETUTCDATE())
```

### Slow Query Detection (SQL)

```sql
SELECT TOP 100
    QueryText,
    AVG(DurationMs) as AvgDuration,
    MAX(DurationMs) as MaxDuration,
    COUNT(*) as ExecutionCount
FROM queries
WHERE timestamp > DATEADD(day, -7, GETUTCDATE())
GROUP BY QueryText
HAVING AVG(DurationMs) > 3000
ORDER BY AvgDuration DESC
```

### Peak Usage Times (SQL)

```sql
SELECT
    DATEPART(hour, timestamp) as Hour,
    COUNT(*) as QueryCount,
    AVG(DurationMs) as AvgDuration
FROM queries
WHERE timestamp > DATEADD(day, -7, GETUTCDATE())
GROUP BY DATEPART(hour, timestamp)
ORDER BY Hour
```

---

## Quick Reference

### KQL Time Shortcuts

| Expression | Meaning |
|------------|---------|
| `ago(1h)` | 1 hour ago |
| `ago(7d)` | 7 days ago |
| `ago(30d)` | 30 days ago |
| `ago(1m)` | 1 minute ago |

### Percentile Interpretation

| Percentile | Meaning |
|------------|---------|
| P50 (median) | Typical user experience |
| P90 | 90% of queries faster than this |
| P99 | Worst case (excluding outliers) |

### SE vs FE Performance Guide

| SE% | FE% | Interpretation |
|-----|-----|----------------|
| >80% | <20% | Efficient - good VertiPaq usage |
| 50-80% | 20-50% | Mixed - review DAX patterns |
| <50% | >50% | FE-heavy - optimization needed |
