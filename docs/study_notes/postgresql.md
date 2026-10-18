# PostgreSQL Study Notes

PostgreSQL is the relational database used by this local project. It stores raw and transformed tables, executes SQL, maintains indexes and statistics, and supports transactions.

## Core Ideas

- Database / schema / table: a database contains schemas; schemas contain tables, views, indexes, and other objects. This project uses the ny_taxi database and default public schema unless configured otherwise.
- Table vs view: a table stores rows; a normal view stores a query definition and computes results when queried. The flagged taxi object is a view.
- Primary key: a declared unique, non-null identifier. The taxi source and clean tables currently have no primary key; do not invent a natural key without checking duplicates and source semantics.
- Transaction: a set of database operations committed or rolled back together.
- WAL: PostgreSQL records changes in a write-ahead log so committed work can be recovered after a crash.
- ANALYZE: updates planner statistics. EXPLAIN shows the planned query; EXPLAIN ANALYZE executes it and reports actual timings.

## Indexes

A B-tree index can accelerate selective lookups and joins, but every insert/update must maintain relevant indexes. Index the workload, not every column. The clean-table script indexes pickup_date because date-based reporting is expected.

## Local Connection Notes

- From Windows or another host process: PostgreSQL is published on localhost:5432.
- From pgAdmin inside the Compose network: use service name pgdatabase and port 5432; localhost would refer to the pgAdmin container itself.
- ./pg_data is a host bind mount for database persistence. Removing containers does not necessarily remove the database files; never delete the data directory as a routine shutdown step.

## Project-Specific Identifier Gotcha

The ingested source has a case-sensitive column named "Airport_fee". PostgreSQL turns unquoted names into lowercase, so airport_fee is not the same identifier. Use "Airport_fee" in SQL. The source also has mixed-case names such as "VendorID", "RatecodeID", and "PULocationID".

## Interview Questions

1. Why can too many indexes hurt ingestion? Each write also updates the indexes, adding I/O and maintenance work.
2. What does ANALYZE do? It refreshes statistics used by the query planner; it does not validate business correctness.
3. How is a view different from a table? A normal view stores the SQL definition rather than a persisted result set.
4. What makes an identifier a primary key? It is unique and non-null for every row, with stable entity semantics.
