# Orchestration, Lakehouse, BI, and Governance

## Orchestrator vs Pipeline Code

Pipeline code performs a unit of work, such as ingesting a file or building a SQL model. An orchestrator schedules and coordinates those units: dependencies, retries, backfills, parameters, status, and alerts. The current repository uses manual CLI and pgAdmin steps; it does not yet contain an orchestrator.

A future workflow might be:

    check source file -> ingest Bronze -> validate load -> build Silver -> run quality checks -> build Gold -> publish status

Each step should be restartable and observable. A retry should not duplicate rows, and a backfill should let an operator rerun a date range deliberately.

## Lakehouse and Databricks

- Data lake: object storage for files in open formats such as Parquet.
- Warehouse: managed analytical storage and SQL engine.
- Lakehouse: combines lake-style files with table management, transactions, and analytical query features.
- Delta Lake: a table format/transaction layer commonly used with Spark/Databricks; learn its semantics before claiming them in a project.
- Databricks notebook: interactive development interface. Jobs/workflows run configured notebooks or code as scheduled production tasks. Notebooks are useful for exploration; repeatable jobs need parameters, dependencies, logging, and controlled outputs.

The current PostgreSQL project demonstrates a local relational batch pipeline, not a Databricks lakehouse.

## BI and Semantic Layer

A semantic layer gives consistent business names and definitions to fields and metrics for BI tools. Dashboard-ready models should have understandable dimensions, stable grains, documented measures, and appropriate access controls. Tableau and Power BI consume these models; the reporting tool should not silently repair source-data quality.

## Governance and Sensitive Data

- Apply least-privilege access and separate development from production credentials.
- Do not commit secrets or real sensitive data to Git.
- Classify data and use approved masking, encryption, retention, and audit practices.
- PII/PHI requires organization-approved access and handling; a public taxi dataset is not a substitute for regulated healthcare data.
- Document source, lineage, owner, metric definitions, refresh cadence, access, assumptions, and known limitations.

## Git and CI/CD

Use branches and reviewable commits; keep SQL, Python, and configuration in version control. A basic data CI pipeline can lint code, validate SQL syntax, run checks on small fixtures, and execute model/data tests in an isolated database. Do not commit large source datasets, credentials, or local database files.

## Interview Questions

1. What does an orchestrator add beyond a Python script? Scheduling, dependencies, retries, backfills, monitoring, and operational state.
2. How would you design a rerunnable workflow? Make each task idempotent, use explicit inputs/partitions, persist run metadata, and validate output counts.
3. What is Delta Lake? A table storage layer with a transaction log and table-management features used with lake data; it is not synonymous with all lakehouses.
4. What belongs in a data product's documentation? Grain, schema, metrics, lineage, owners, refresh behavior, access, assumptions, quality checks, and limitations.
5. How should PHI be handled? Follow approved classification, access, encryption, minimization, retention, and audit controls; never use it in an unapproved environment.
