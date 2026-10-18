# Python Ingestion Study Notes

The current ingest.py is a parameterized batch loader. It uses PyArrow to iterate Parquet batches, Pandas to_sql to write batches, SQLAlchemy to connect to PostgreSQL, and argparse to expose CLI settings.

## Current Behavior

- Default chunk size is 50,000 rows.
- Supports local paths, URL input, glob patterns, and year/month lookup under nyc_taxi_data/.
- Supports CSV and Parquet input.
- if_exists append is the default; rerunning the same input can duplicate rows.
- if_exists replace replaces the target table on the first file and appends subsequent files in that run.
- It does not yet maintain a file manifest, deduplicate source files, use a formal schema contract, or implement retries/quarantine.

Example:

    uv run python ingest.py --year 2025 --month 1 --taxi_type yellow \
      --table_name yellow_taxi_trips_2025_01 --if_exists replace

## Engineering Concepts

- Batching bounds memory and amortizes database overhead; choose batch size based on memory, row width, and write performance.
- Streaming/generator yields work incrementally rather than materializing the full dataset.
- Idempotency means rerunning the same input produces the same final result without duplicates or unintended side effects. Replace mode helps for a single table rebuild but is not a complete multi-file load registry.
- A schema contract defines names, types, nullability, and accepted-value rules. Type inference from the first batch can cause drift or identifier casing surprises.
- Retry transient failures with backoff, not permanent schema/data errors.
- Observability logs input file, run ID, rows read/written, duration, failures, and validation counts.
- Quarantine preserves rejected rows with reasons rather than losing them or crashing the whole load.

## Improvements to Study Next

1. Use environment variables or a secret manager for credentials instead of defaults in code/CLI history.
2. Add an ingestion manifest with file name, checksum, load time, and row counts.
3. Define PostgreSQL column types explicitly and decide how to handle schema evolution.
4. Add a retry policy, clear transaction boundaries, and failure recovery semantics.
5. Add structured logging and separate read/accepted/rejected/written counts.

## Interview Questions

1. Why iterate Parquet in batches? It bounds memory and lets the loader process data incrementally.
2. What risk comes with append mode? A rerun can duplicate records unless the job tracks files or enforces idempotency.
3. How would you handle malformed rows? Validate against a contract, write invalid rows and reasons to quarantine, and report counts.
4. Why are explicit destination types useful? They make schema behavior predictable across files and batches.
