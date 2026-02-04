# Day 1: Microsoft Fabric Fundamentals

This document provides foundational resources and reference materials for understanding Microsoft Fabric as a unified analytics platform.

---

## Overview

Microsoft Fabric is an end-to-end analytics platform that integrates data engineering, data science, real-time intelligence, data warehousing, and business intelligence into a single SaaS experience. All workloads operate on a shared storage layer called OneLake.

---

## Core Concepts

### What is Microsoft Fabric?

Microsoft Fabric is a software-as-a-service (SaaS) platform that supports end-to-end data workflows including ingestion, transformation, real-time stream processing, analytics, and reporting. It eliminates the need to integrate multiple separate services by providing a unified environment where all analytics capabilities work together seamlessly.

**Key characteristics:**
- Single platform for all data and analytics workloads
- Built-in governance and security through Microsoft Purview
- Copilot integration for AI-assisted development
- Microsoft 365 integration (Excel, Teams)

**Documentation:** [What is Microsoft Fabric?](https://learn.microsoft.com/en-us/fabric/get-started/microsoft-fabric-overview)

---

### OneLake: The Foundation

OneLake is the centralized, logical data lake that serves as the storage foundation for all Fabric workloads. Think of it as "OneDrive for data" - every Fabric tenant has a single OneLake that eliminates data silos.

**Key points:**
- Built on Azure Data Lake Storage Gen2
- Single namespace across the entire tenant
- No need to provision storage separately
- Supports shortcuts to external data sources without data duplication
- Data stored in open Delta Lake format

**Documentation:** [What is OneLake?](https://learn.microsoft.com/en-us/fabric/onelake/onelake-overview)

---

### Lakehouse Architecture

A Lakehouse combines the flexibility of a data lake with the performance and structure of a data warehouse. It stores both structured and unstructured data in a unified location using Delta tables.

**Features:**
- Automatic table discovery and registration
- SQL analytics endpoint for T-SQL queries
- Integration with Apache Spark for large-scale processing
- Default semantic model for Power BI integration

**Documentation:** [What is a Lakehouse?](https://learn.microsoft.com/en-us/fabric/data-engineering/lakehouse-overview)

---

### Data Factory

Data Factory in Fabric provides data integration capabilities for building ETL/ELT pipelines. It connects to over 170 data sources and supports both cloud and on-premises data through gateways.

**Capabilities:**
- Copy activity for bulk data movement
- Dataflows Gen2 for low-code transformations
- Pipeline orchestration with control flow logic
- Apache Airflow integration for code-based orchestration

**Documentation:** [What is Data Factory in Microsoft Fabric?](https://learn.microsoft.com/en-us/fabric/data-factory/data-factory-overview)

---

### Data Warehouse

Fabric Data Warehouse is an enterprise-scale relational warehouse that uses the SQL Database Engine for T-SQL support including full ACID transactions, stored procedures, and materialized views.

**Characteristics:**
- Data stored in Delta tables (open format)
- Separation of compute and storage
- Cross-database queries across multiple sources
- Integration with Power BI for reporting

**Documentation:** [What is Fabric Data Warehouse?](https://learn.microsoft.com/en-us/fabric/data-warehouse/data-warehousing)

---

## Fabric Workloads

| Workload | Purpose | Target Audience |
|----------|---------|-----------------|
| **Power BI** | Interactive dashboards and reports | Business Analysts |
| **Data Factory** | Data ingestion and transformation | Data Engineers |
| **Data Engineering** | Apache Spark processing, notebooks | Data Engineers |
| **Data Warehouse** | Relational analytics with T-SQL | Data Engineers, DBAs |
| **Data Science** | ML model development and deployment | Data Scientists |
| **Real-Time Intelligence** | Streaming data analytics | Data Engineers |

---

## Learning Resources

### Microsoft Learn Training Path

**Get started with Microsoft Fabric** (10 hours)  
A comprehensive learning path covering all major Fabric capabilities.

**Modules included:**
1. Introduction to end-to-end analytics using Microsoft Fabric (20 min)
2. Get started with lakehouses in Microsoft Fabric (59 min)
3. Use Apache Spark in Microsoft Fabric (1 hr 20 min)
4. Work with Delta Lake tables in Microsoft Fabric (1 hr 8 min)
5. Orchestrate processes and data movement with Microsoft Fabric (1 hr 22 min)
6. Ingest Data with Dataflows Gen2 in Microsoft Fabric (1 hr)
7. Get started with data warehouses in Microsoft Fabric (1 hr 13 min)
8. Get started with Real-Time Intelligence in Microsoft Fabric (1 hr 13 min)
9. Get started with data science in Microsoft Fabric (46 min)
10. Administer a Microsoft Fabric environment (41 min)

**Link:** [Get started with Microsoft Fabric - Learning Path](https://learn.microsoft.com/en-us/training/paths/get-started-fabric/)

---

### Additional Documentation

| Topic | Link |
|-------|------|
| Fabric Terminology | [Microsoft Fabric terminology](https://learn.microsoft.com/en-us/fabric/fundamentals/fabric-terminology) |
| Create a Workspace | [Create workspaces](https://learn.microsoft.com/en-us/fabric/fundamentals/create-workspaces) |
| End-to-End Tutorials | [End-to-end tutorials](https://learn.microsoft.com/en-us/fabric/fundamentals/end-to-end-tutorials) |
| Fabric Trial | [Start a Fabric trial](https://learn.microsoft.com/en-us/fabric/get-started/fabric-trial) |
| OneLake Shortcuts | [OneLake shortcuts](https://learn.microsoft.com/en-us/fabric/onelake/onelake-shortcuts) |

---

### Hands-On Workshop

**Fabric Analyst in a Day (FAIAD)**  
A free, hands-on training workshop for analysts working with Power BI and Fabric. Covers working with lakehouses, creating reports, and analyzing data in the Fabric environment.

**Link:** [Fabric Analyst in a Day](https://aka.ms/LearnFAIAD)

---

### Certification

**Microsoft Certified: Fabric Data Engineer Associate**  
Validates expertise with data loading patterns, data architectures, and orchestration processes in Microsoft Fabric.

**Link:** [Fabric Data Engineer Associate](https://learn.microsoft.com/en-us/credentials/certifications/fabric-data-engineer-associate/)

---

## Architecture Reference

### Data Hierarchy in OneLake

```
Tenant (Organization)
└── Workspaces (similar to folders)
    └── Lakehouses
        ├── Files (unstructured data)
        └── Tables (Delta tables)
```

### Integration Points

- **Power Query**: Data transformation in Dataflows
- **Apache Spark**: Large-scale data processing
- **T-SQL**: Relational queries via SQL analytics endpoint
- **Python/R**: Data science notebooks
- **DAX**: Semantic model calculations

---

## Decision Guidance

### Warehouse vs. Lakehouse

| Choose Warehouse when... | Choose Lakehouse when... |
|--------------------------|--------------------------|
| Need enterprise-scale relational analytics | Have highly unstructured data |
| Star/snowflake schema design | Spark is primary development tool |
| Full T-SQL DDL/DML support required | Need flexibility for varied file formats |
| Corporate data marts and governed models | Data science and ML workloads |

**Reference:** [Decision guide: Choose between Warehouse and Lakehouse](https://learn.microsoft.com/en-us/fabric/fundamentals/decision-guide-lakehouse-warehouse)

---

## Quick Links

- [Microsoft Fabric Portal](https://app.fabric.microsoft.com/)
- [Fabric Documentation](https://learn.microsoft.com/en-us/fabric/)
- [Fabric Blog](https://blog.fabric.microsoft.com/)
- [Fabric Community](https://community.fabric.microsoft.com/)

---

*Last updated: February 2026*

---

*Compiled by Michael Lindner*
