# =============================================================================
# Day 2 - Module 4 - SQL Queries for Workspace Monitoring
# =============================================================================
# These SQL queries can be used via the Lakehouse SQL Analytics Endpoint
# for users who prefer SQL over KQL.

# -----------------------------------------------------------------------------
# Exercise 4.3.1: Basic Performance Overview (SQL Version)
# -----------------------------------------------------------------------------

-- Performance summary for last 24 hours
SELECT 
    COUNT(*) AS TotalQueries,
    ROUND(AVG(CAST(DurationMs AS FLOAT)), 0) AS AvgDurationMs,
    MAX(DurationMs) AS MaxDuration,
    COUNT(DISTINCT ExecutingUser) AS UniqueUsers
FROM queries
WHERE timestamp > DATEADD(day, -1, GETUTCDATE())

# -----------------------------------------------------------------------------
# Exercise 4.3.2: Find Slow Queries (SQL Version)
# -----------------------------------------------------------------------------

-- Slow queries (>5 seconds)
SELECT TOP 10
    ItemName,
    LEFT(QueryText, 150) AS QueryPreview,
    COUNT(*) AS ExecutionCount,
    ROUND(AVG(CAST(DurationMs AS FLOAT)), 0) AS AvgDuration,
    MAX(DurationMs) AS MaxDuration
FROM queries
WHERE timestamp > DATEADD(day, -7, GETUTCDATE())
  AND DurationMs > 5000
GROUP BY ItemName, LEFT(QueryText, 150)
ORDER BY AvgDuration DESC

# -----------------------------------------------------------------------------
# Exercise 4.3.3: Storage Engine vs Formula Engine (SQL Version)
# -----------------------------------------------------------------------------

-- SE vs FE percentage analysis
SELECT 
    ItemName,
    COUNT(*) AS QueryCount,
    ROUND(AVG(100.0 * StorageEngineDurationMs / DurationMs), 1) AS AvgSEPercent,
    ROUND(AVG(100.0 * FormulaEngineDurationMs / DurationMs), 1) AS AvgFEPercent
FROM queries
WHERE timestamp > DATEADD(day, -7, GETUTCDATE())
  AND DurationMs > 1000
GROUP BY ItemName
ORDER BY AvgFEPercent DESC

# -----------------------------------------------------------------------------
# Exercise 4.4.1: Top Users (SQL Version)
# -----------------------------------------------------------------------------

-- Top users by query count
SELECT TOP 20
    ExecutingUser,
    COUNT(*) AS QueryCount,
    ROUND(AVG(CAST(DurationMs AS FLOAT)), 0) AS AvgDuration,
    SUM(CpuTimeMs) AS TotalCpuMs,
    COUNT(DISTINCT ItemName) AS UniqueModels
FROM queries
WHERE timestamp > DATEADD(day, -7, GETUTCDATE())
GROUP BY ExecutingUser
ORDER BY QueryCount DESC

# -----------------------------------------------------------------------------
# Exercise 4.4.2: Application Breakdown (SQL Version)
# -----------------------------------------------------------------------------

-- Queries by application
SELECT 
    Application,
    COUNT(*) AS QueryCount,
    ROUND(AVG(CAST(DurationMs AS FLOAT)), 0) AS AvgDuration,
    COUNT(DISTINCT ExecutingUser) AS UniqueUsers
FROM queries
WHERE timestamp > DATEADD(day, -7, GETUTCDATE())
GROUP BY Application
ORDER BY QueryCount DESC

# -----------------------------------------------------------------------------
# Exercise 4.5: Hourly Usage Pattern (SQL Version)
# -----------------------------------------------------------------------------

-- Queries by hour of day
SELECT 
    DATEPART(hour, timestamp) AS HourOfDay,
    COUNT(*) AS QueryCount,
    ROUND(AVG(CAST(DurationMs AS FLOAT)), 0) AS AvgDuration,
    COUNT(DISTINCT ExecutingUser) AS UniqueUsers
FROM queries
WHERE timestamp > DATEADD(day, -7, GETUTCDATE())
GROUP BY DATEPART(hour, timestamp)
ORDER BY HourOfDay

# -----------------------------------------------------------------------------
# Additional: User Activity by Day of Week (SQL Version)
# -----------------------------------------------------------------------------

-- Activity by day of week
SELECT 
    DATENAME(weekday, timestamp) AS DayOfWeek,
    DATEPART(weekday, timestamp) AS DayNumber,
    COUNT(*) AS QueryCount,
    COUNT(DISTINCT ExecutingUser) AS UniqueUsers
FROM queries
WHERE timestamp > DATEADD(day, -30, GETUTCDATE())
GROUP BY DATENAME(weekday, timestamp), DATEPART(weekday, timestamp)
ORDER BY DayNumber

# -----------------------------------------------------------------------------
# Additional: Error Analysis (SQL Version)
# -----------------------------------------------------------------------------

-- Query errors by status code
SELECT 
    StatusCode,
    ItemName,
    COUNT(*) AS ErrorCount,
    COUNT(DISTINCT ExecutingUser) AS AffectedUsers,
    MIN(timestamp) AS FirstOccurrence,
    MAX(timestamp) AS LastOccurrence,
    CASE StatusCode
        WHEN 400 THEN 'Bad Request - Query syntax error'
        WHEN 401 THEN 'Unauthorized - Permission issue'
        WHEN 403 THEN 'Forbidden - Access denied'
        WHEN 408 THEN 'Timeout - Query took too long'
        WHEN 429 THEN 'Too Many Requests - Rate limited'
        WHEN 500 THEN 'Internal Error - Model issue'
        WHEN 503 THEN 'Service Unavailable'
        ELSE 'Unknown error'
    END AS ErrorType
FROM queries
WHERE timestamp > DATEADD(day, -7, GETUTCDATE())
  AND Status != 'Success'
GROUP BY StatusCode, ItemName
ORDER BY ErrorCount DESC
