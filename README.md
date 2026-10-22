# NYC Taxi Data Ingestion & Analytics Pipeline

An end-to-end containerized batch data ingestion and relational analytics pipeline built with **Docker**, **PostgreSQL**, **pgAdmin**, and **Python**.

This project is part of the **Data Engineering Zoomcamp (Module 1)** curriculum, focusing on reproducible infrastructure, containerized relational databases, and memory-safe data ingestion workflows.

---

## Architecture Overview

```mermaid
flowchart LR
    subgraph Storage ["1. Raw Data Sources"]
        A["NYC Taxi Parquet/CSV"]
        B["Taxi Zone Lookup CSV"]
    end

    subgraph DockerEnv ["2. Docker Network (pg-network)"]
        direction TB
        C["Ingestion Engine\n(Python, Pandas, SQLAlchemy)"]
        D[("PostgreSQL 16\n(Port: 5432)")]
        E["pgAdmin 4\n(Web UI: Port 8080)"]
        
        C -->|Batch / Chunked Insert| D
        E -->|Query & Visual Inspection| D
    end

    subgraph Analytics ["3. Downstream Analytics"]
        F["SQL Queries & Aggregations"]
    end

    A --> C
    B --> C
    D --> F
```

---

## Tech Stack

| Component | Technology | Purpose |
| :--- | :--- | :--- |
| **Containerization** | Docker, Docker Compose | Service isolation, networking, and reproducible environments |
| **Database** | PostgreSQL 16 | Relational OLTP database for structured taxi trip records |
| **Database UI** | pgAdmin 4 | Web interface for database inspection and query execution |
| **Ingestion Engine** | Python 3.13 / `uv` | Chunked batch ingestion using Pandas and SQLAlchemy |
| **Shell & Scripting** | GNU Bash (Git Bash) | Environment automation, service control, and CLI tooling |
| **BI & Reporting** | Power BI Desktop | Import-mode dashboard over the Gold daily-demand model |

---

## Repository Structure

```
postgres_docker/
├── README.md
├── docker-compose.yaml      # PostgreSQL and pgAdmin services
├── ingest.py                # Chunked CLI ingestion (Parquet and CSV)
├── download_data.py         # Dataset downloader
├── fix_parts.py             # Recovery helper for partial downloads
├── Dashboard.pbix           # Earlier Power BI report
├── Final Dashboard NYC Taxi Data.pbix
├── sql/                     # Silver, profiling, flags, Gold, analysis, star schema
└── docs/                    # Workflow, dashboard, model, and study notes
```

Downloaded source files and database volumes are local working data and are excluded from Git.

---

## Getting Started

### 1. Prerequisites
Ensure you have the following installed on your machine:
* **Docker Desktop** (running)
* **Git Bash** (recommended terminal on Windows)
* **Python 3.13+** or **uv**

### 2. Environment Setup (Git Bash)
Clone the repository and enter the working directory:
```bash
git clone https://github.com/YaadiY/postgres_docker.git
cd postgres_docker
```

### 3. Start Database & UI Infrastructure
Launch the PostgreSQL and pgAdmin containers in detached mode:
```bash
docker compose up -d
```
* **PostgreSQL:** Accessible on `localhost:5432` (User: `root`, DB: `ny_taxi`)
* **pgAdmin 4:** Accessible on [http://localhost:8080](http://localhost:8080) (Login: `root@root.com`, Password: `root`)
* *Internal Docker Hostname:* `pgdatabase` on network `pg-network`

To stop services:
```bash
docker compose down
```

### 4. Download NYC Taxi Datasets
Use the multi-threaded downloader script to fetch Parquet datasets directly into `nyc_taxi_data/`:
```bash
# Download a single year of Yellow Taxi data (e.g. 2024)
uv run python download_data.py --types yellow --start-year 2024 --end-year 2024

# Download full archive across all services (Yellow, Green, FHV, High-Volume FHV) from 2009 to present
uv run python download_data.py --types all --start-year 2009 --end-year 2026 --workers 6

# Preview downloads without downloading (Dry Run)
uv run python download_data.py --types yellow green --start-year 2024 --end-year 2024 --dry-run
```

### 5. Run Chunked Data Ingestion
Stream dataset files directly into PostgreSQL using the CLI engine:
```bash
# Ingest Taxi Zone Lookup (CSV)
uv run python ingest.py --table_name zones --url taxi_zone_lookup.csv

# Ingest Yellow Taxi Trips (Parquet, ~3.72M records)
uv run python ingest.py --table_name yellow_taxi_trips --url nyc_taxi_data/yellow_tripdata_2024-01.parquet

# Ingest one month by year and month (replaces the target table on the first file)
uv run python ingest.py --year 2025 --month 1 --taxi_type yellow --table_name yellow_taxi_trips_2025_01 --if_exists replace
```

### 6. Build a Clean Analytics Table
Run [`sql/clean_yellow_taxi_2025.sql`](sql/clean_yellow_taxi_2025.sql) in pgAdmin's Query Tool after loading `yellow_taxi_trips_2025_01`. It preserves the ingested table and rebuilds `yellow_taxi_trips_2025_01_clean`, filtering out-of-month pickups, invalid time order, and negative or missing trip distances. The clean table also includes pickup date, trip duration, and pickup/dropoff zone names. See the [data quality workflow](docs/data_quality_workflow.md) for the current database snapshot, validation approach, and next steps.

### 7. Profile the Clean Data
Run [`sql/profile_yellow_taxi_2025_01.sql`](sql/profile_yellow_taxi_2025_01.sql) in pgAdmin to review nulls, unusual values, percentiles, and sample outliers. The profile is read-only; it helps distinguish records to flag for review from records that should be excluded by a documented rule.

Run [`sql/flag_yellow_taxi_2025_01.sql`](sql/flag_yellow_taxi_2025_01.sql) to create a review view with provisional anomaly flags. It preserves every flagged trip and does not delete data.

Run [`sql/explore_distribution_yellow_taxi_2025_01.sql`](sql/explore_distribution_yellow_taxi_2025_01.sql) to compare averages, medians, percentiles, IQR fences, and distance buckets when investigating outliers.

Current quality review: negative fares among January Flex Fare trips (`payment_type = 0`) are concentrated in Vendor 2, and negative totals in that group are especially concentrated on January 1. This is documented as an unresolved source-data pattern; flagged rows remain in the dataset while the payment and fare reporting semantics are investigated. See the [data quality workflow](docs/data_quality_workflow.md) for counts, hourly patterns, and the component-sum check.

---

### Study Notes and Interview Preparation

Use the [study-notes index](docs/study_notes/README.md) for separate notes on this pipeline's Bronze/Silver/Gold layers, SQL, PostgreSQL, Docker, Python ingestion, Bash, Kafka, data modeling, orchestration, lakehouse concepts, governance, and interview practice. The notes distinguish what this repository implements today from topics that are still study goals.

### Gold Reporting View

The [Gold SQL model](sql/gold_yellow_taxi_daily_demand_2025_01.sql) creates the daily demand view at one row per pickup date, pickup borough/zone, dropoff borough/zone, and payment type. It includes trip totals and review counts. Validation against the January Silver table confirmed all 3,475,080 source rows are represented across 463,623 Gold groups; the review-flag, negative-fare, and negative-total counts also match the Silver and flagged views. Revenue measures are omitted until negative-fare and Flex Fare behavior has a documented business treatment. See the [data-quality workflow](docs/data_quality_workflow.md) for the checks and their limits.

Use [`sql/analyze_gold_yellow_taxi_2025_01.sql`](sql/analyze_gold_yellow_taxi_2025_01.sql) for read-only exploration of daily totals, weekday averages, and weekday demand by pickup borough.

### Trip-Level Star Schema

After building the January Silver table, run [`sql/star_schema_yellow_taxi_2025_01.sql`](sql/star_schema_yellow_taxi_2025_01.sql) in pgAdmin to create `analytics.dim_date`, `analytics.dim_location`, `analytics.dim_payment_type`, and `analytics.fact_yellow_taxi_trip_2025_01`. The fact grain is one row per Silver row; its generated key is a warehouse surrogate, because the source has no declared trip primary key. The model retains raw fare components and quality flags without claiming a finalized revenue metric. See [data modeling notes](docs/study_notes/modeling_and_quality.md) for the keys, grain, and assumptions.

To visualize the daily totals, follow the [first Power BI chart walkthrough](docs/dashboard_first_chart.md).

### Power BI Executive Analytics Dashboard

The project delivers an interactive BI reporting layer via [`Final Dashboard NYC Taxi Data.pbix`](Final%20Dashboard%20NYC%20Taxi%20Data.pbix) built on top of the reconciled January 2025 Gold daily-demand model (`gold_yellow_taxi_daily_demand_2025_01`):

#### 1. Key Metrics & Executive KPIs
* **Total Trips (Volume):** **3.475M** verified rides across January 2025.
* **Daily Average Demand:** **112.099K** trips per day.
* **Data Quality Tracking:** Integrated monitoring of review-flagged rides (~20–30% peak anomaly rate, capturing Vendor 2 Flex Fare and negative totals).

#### 2. Visual Architecture & Insights
* **Daily Demand Trend (`Sum of Trips by Day`):**
  - Line visual tracking daily trips from Jan 1 through Jan 31.
  - Highlights mid-month cyclical peaks reaching ~140K trips/day and post-weekend drops (~80K–90K trips).
* **Data Quality & Anomaly Trend (`Total Trips and Pct Trips With Review Flags`):**
  - Dual-axis combo chart tracking total volume alongside anomaly flag percentages to evaluate operational risks and vendor discrepancies across the month.
* **Pickup Zone Demand Hierarchy (`Total Trips & % of Borough Pickups`):**
  - Top N horizontal bar chart ranking high-density mobility zones:
    1. **Midtown Center** (~170K trips)
    2. **Upper East Side South** (~160K trips)
    3. **Upper East Side North** (~155K trips)
    4. **JFK Airport** (~135K trips)
    5. **Times Sq / Theatre District** (~125K trips)
* **Borough & Weekday Demand Distribution:**
  - Clustered bar chart showing average daily volume stratified by borough (Manhattan overwhelmingly leads with ~100K+ daily rides, followed by Queens with airport corridors, Brooklyn, and Bronx).
* **Multi-Dimensional Slice & Dice:**
  - Interactive grid slicers for **Weekday** (Mon–Sun), **Day of Month** (1–31 slider), and **Pickup Borough** (Manhattan, Queens, Brooklyn, Bronx, Staten Island, EWR).

#### 3. Power BI Star Schema & Modeling Notes
* **Dimensions:** `DimDate` (calendar hierarchy), `DimPickupLocation` (distinct composite borough/zone keys), and `DimDropoffLocation`.
* **Grain Integrity:** Uses distinct composite borough/zone pairs rather than joining on duplicate text lookup names, preventing fact multiplication and reconciling to the exact **3,475,080** Silver row count.
* Detailed setup, DAX definitions, and reconciliation checks are documented in the [Power BI Dashboard Guide](docs/power_bi_dashboard_model.md).

---

- [x] Repository initialization & Git configuration
- [x] Git ignore rules for large dataset files (`.parquet`, `.csv`)
- [x] Docker Compose setup for PostgreSQL 16 & pgAdmin 4
- [x] Chunked data ingestion script (`ingest.py`)
- [x] Multi-threaded dataset downloader with resuming & validation (`download_data.py`)
- [x] January Silver quality review and reconciled Gold daily-demand view
- [ ] Multi-month full dataset batch ingestion automation
- [ ] Dockerizing the ingestion pipeline (`Dockerfile`)
- [ ] Analytical SQL queries & homework validation
