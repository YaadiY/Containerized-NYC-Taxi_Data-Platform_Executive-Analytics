# Session Checkpoint: Module 1 DE Zoomcamp

**Date:** October 16, 2026  
**Status:** Milestone 3 & 4 Completed Successfully

---

## 1. Quick Revision Summary (What We Built Tonight)

```mermaid
flowchart LR
    subgraph Host ["Host (Windows / uv)"]
        F1["taxi_zone_lookup.csv (265 rows)"]
        F2["yellow_tripdata_2026-01.parquet (3.72M rows)"]
        ING["ingest.py\n(PyArrow iter_batches)"]
        
        F1 --> ING
        F2 --> ING
    end

    subgraph Docker ["Docker Network (pg-network)"]
        PG[("PostgreSQL 16\n(Port 5432 / localhost)")]
        PGA["pgAdmin 4\n(Port 8080 / localhost)"]
        
        ING -->|100k row chunks| PG
        PGA -->|Internal DNS: pgdatabase:5432| PG
    end
```

### Key Engineering Concepts Mastered:
1. **Multi-Container Orchestration (`docker-compose.yaml`):**
   * Configured PostgreSQL 16 and pgAdmin 4.
   * Bound `./pg_data` to `/var/lib/postgresql/data` for persistent database storage on your drive.
   * User-defined bridge network `pg-network` allowing containers to discover each other via internal DNS (`pgdatabase:5432`).
2. **Memory-Safe Batch Ingestion (`ingest.py`):**
   * Avoided the $O(N)$ RAM trap by streaming chunks of 100,000 rows with `pyarrow.parquet.ParquetFile.iter_batches()`.
   * Fully parameterized with `argparse` (`--user`, `--password`, `--host`, `--port`, `--db`, `--table_name`, `--url`, `--chunksize`).
3. **Current Ingested State in PostgreSQL (`ny_taxi`):**
   * Table `zones`: **265 rows**
   * Table `yellow_taxi_trips`: **3,724,889 rows** (~3.72 Million records)
4. **Interview Preparation Guide:**
   * Created [`docs/module1_interview_qa.md`](file:///c:/Users/yeleg/VS/postgres_docker/docs/module1_interview_qa.md) covering Docker internals, OOM killer (Exit 137), B-Tree indexes, and WAL logging.

---

## 2. Agenda for Tomorrow

1. **2-Minute Warmup Revision:**
   * Rapid review of Docker bridge networking, bind mounts vs volumes, and batch chunking.
2. **Importing ALL NYC Taxi Data:**
   * How the NYC TLC URL pattern works:  
     `https://d37ci6vzurychx.cloudfront.net/trip-data/yellow_tripdata_{YEAR}-{MONTH}.parquet`
   * Automating multi-month ingestion via a loop script or CLI range without downloading giant files manually.
3. **Dockerizing the Ingestion Engine (`Dockerfile`):**
   * Package `ingest.py` into a lightweight container.
   * Run the ingestion pipeline *inside* the Docker network directly targeting `pgdatabase:5432`.
4. **Analytical SQL Queries (Zoomcamp Homework & Analytics):**
   * Validating pickup zones, largest tips, and longest trip distances using SQL.

---

## 3. End-of-Day Shutdown Commands

To cleanly shut down your database containers tonight:
```bash
docker compose down
```
*(Your data in `./pg_data` is saved and will immediately reload tomorrow when you run `docker compose up -d`!)*
