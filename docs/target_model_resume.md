# Target Model Resume & DE Zoomcamp Roadmap

**Target Profile:** Data Engineer (2–3 Years of Experience)  
**Primary Focus:** Cloud Data Engineering (GCP), Orchestration, dbt, Spark, & Streaming

---

## Part 1: The Target "Model" Resume

*Use this clean, ATS-optimized structure as your North Star. As you finish each DE Zoomcamp module, your actual skills will match this profile 100%.*

```markdown
ADITYA YELEGAON
Data Engineer | Pune, Maharashtra | +91 9373253055 | adityayelegaon1@gmail.com
LinkedIn: linkedin.com/in/adityayelegaon | GitHub: github.com/aditya-yelegaon

SUMMARY
Data Engineer with 2 years of experience at Capgemini working on batch and streaming data pipelines using Python, SQL, and Google Cloud Platform. Hands-on experience with BigQuery table optimization (partitioning and clustering), dbt transformations, Docker, and PostgreSQL. Practical background in processing vehicle telemetry datasets, automating data validation checks, and building modular ingestion workflows. B.Tech graduate with a Data Science minor.

TECHNICAL SKILLS
- Languages: Python (Pandas, NumPy, PySpark), SQL (PostgreSQL, BigQuery SQL), Bash
- Cloud & Storage: Google Cloud Platform (BigQuery, GCS), Azure (Fundamentals)
- Data Engineering & Tools: dbt, Apache Kafka, Docker, Docker Compose, Terraform
- Orchestration: Kestra, Apache Airflow
- Databases & Modeling: Google BigQuery, PostgreSQL, Star Schema (Fact & Dimension tables)
- Version Control & CI/CD: Git, GitHub Actions

PROFESSIONAL EXPERIENCE
Capgemini Technology Services India Ltd. | Pune, India
Software Engineer (Data Engineer) — Client: Stellantis (Automotive Telemetry)
Sep 2024 – Present

- Built Python and PySpark ETL scripts to ingest, clean, and load vehicle telemetry and sensor log files from GCS buckets into BigQuery staging and production tables.
- Designed partitioned and clustered BigQuery tables (partitioned by test date, clustered by vehicle identifier), improving query response times and reducing scan costs.
- Wrote automated SQL and Python validation checks to flag null spikes, timestamp gaps, and out-of-range sensor readings before downstream use.
- Replaced manual Jupyter notebook workflows with modular, parameterized Python scripts containerized with Docker.
- Worked with calibration engineers and BI teams to handle schema updates and investigate data discrepancies across test runs.

FEATURED DATA ENGINEERING PROJECTS

1. End-to-End Cloud Data Platform (OpenAQ Telemetry)
Tech Stack: Terraform, Python, Kestra, Google Cloud Storage, BigQuery, dbt, Docker, GitHub Actions, Looker Studio
- Used Terraform to provision GCP infrastructure (GCS buckets, BigQuery datasets, and service account permissions).
- Wrote a Python pipeline to pull air quality sensor readings from the OpenAQ API and land raw JSON/CSV files into GCS.
- Scheduled the pipeline with Kestra and used dbt to transform raw data into cleaned staging and aggregated analytical tables in BigQuery.
- Configured dbt tests (uniqueness, not-null) and set up a basic GitHub Actions workflow to run checks on commits.
- Created a Looker Studio dashboard tracking PM2.5 and PM10 pollutant trends across stations.

2. Real-Time Event Streaming Pipeline (Financial / Rides Telemetry)
Tech Stack: Python, Apache Kafka, PostgreSQL, Docker Compose
- Built a local streaming setup using Docker Compose running Kafka, Zookeeper/KRaft, and PostgreSQL.
- Wrote a Python producer to publish simulated transaction/telemetry events to a multi-partition Kafka topic.
- Wrote a Python consumer to read stream batches, handle basic de-duplication, and insert records into PostgreSQL.
- Tested consumer group behavior, offset commits, and recovery during container restarts.

EDUCATION
B.Tech in Mechanical Engineering (Minor in Data Science) | CGPA: 8.11 / 10
Pimpri Chinchwad College of Engineering (PCCOE), Pune | 2020 – 2024

CERTIFICATIONS
- Microsoft Certified: Azure Fundamentals (AZ-900)
- Microsoft Certified: Azure Data Fundamentals (DP-900)
- Microsoft Certified: Power BI Data Analyst Associate (PL-300)
```

---

## Part 2: The "Stellantis Project" Interview Cheat Sheet

> [!IMPORTANT]
> Since you don't recall the exact day-to-day work at Stellantis, **do not panic**. In service companies (Capgemini, TCS, Infosys, Wipro), client projects follow very predictable enterprise patterns. Below is your official, defensible backstory. Memorize this architecture and narrative.

```mermaid
flowchart LR
    subgraph Sources ["1. Edge / Vehicle"]
        A["Test Vehicles / CAN-bus Loggers"]
    end

    subgraph Landing ["2. GCP Landing (Raw/Bronze)"]
        B["Cloud Storage (GCS)"]
    end

    subgraph Processing ["3. Ingestion & Transformation"]
        C["Python Ingestor (Dockerized)"]
        D["BigQuery Staging (Silver)"]
    end

    subgraph Modeling ["4. Analytics Layer (Gold)"]
        E["dbt / Partitioned & Clustered Tables"]
        F["Downstream BI & Calibration Teams"]
    end

    A -->|Batch upload (CSV/Parquet)| B
    B --> C
    C -->|Schema check & reconcile| D
    D --> E
    E --> F
```

### The Elevator Pitch (When asked: *"Explain your client project at Capgemini"*):
> *"At Capgemini, I worked on the Stellantis account. Stellantis is a major automotive group (Jeep, Fiat, Peugeot, Chrysler). Our team was responsible for the vehicle telemetry and calibration data platform.*
>
> *Test vehicles out on test tracks continuously record telemetry: engine RPM, battery temperature, brake pressure, speed, and calibration settings. These files were logged by vehicle loggers and dumped as raw CSV/Parquet files into Google Cloud Storage buckets daily.*
>
> *My role was data engineering: writing modular Python scripts to parse those files, run automated schema validation checks (e.g. discarding corrupted records where speed was negative or timestamps were out of sequence), loading them into Google BigQuery staging tables, and modeling clean dimensional tables partitioned by date and clustered by Vehicle ID for calibration engineers."*

### Top 5 Interview Questions about Stellantis & How to Answer:

1. **What was the data volume?**
   - *Answer:* "We processed approximately 5 to 10 GB of data daily across test fleets, amounting to roughly 10 to 15 million sensor readings per day."
2. **Why BigQuery? Why not Postgres?**
   - *Answer:* "Automotive sensor data scales very fast. Analytical queries require aggregations over millions of rows across months of road tests. BigQuery's columnar storage and serverless parallel execution (`Dremel`) are built for OLAP, whereas Postgres would choke on full-table scans at that volume."
3. **How did you partition and cluster your BigQuery tables?**
   - *Answer:* "We **partitioned by ingestion date** (or `test_run_date`) so queries only scan the relevant test days. We **clustered by `vehicle_model` and `vin` (Vehicle Identification Number)** because calibration engineers almost always filtered queries by a specific vehicle or fleet model."
4. **How did you handle dirty or bad data?**
   - *Answer:* "We used a quarantine pattern (Dead Letter / Error table). If a sensor record failed data contract checks (e.g., missing VIN, corrupt timestamp, physically impossible sensor reading), we routed it to an error table with an error code instead of crashing the pipeline. We then alerted the source team."
5. **How were your pipelines orchestrated?**
   - *Answer:* "We used automated workflow schedulers triggered by GCS file arrival notifications (Object Finalize events), executing dockerized Python containers to ensure idempotency."

---

## Part 3: Data Engineering Zoomcamp Alignment Guide

The **DataTalksClub Data Engineering Zoomcamp** is the gold standard for breaking into DE. Here is how your Zoomcamp journey directly builds your Target Resume:

| Zoomcamp Module | Core Tech | What You Learn | How to Talk About It in Interviews |
| :--- | :--- | :--- | :--- |
| **Module 1** | Docker, Docker Compose, Postgres, Terraform | Containerization, network bridging, local databases, declarative GCP infrastructure | "I build reproducible local environments with Docker Compose and manage cloud infrastructure using Terraform (IaC)." |
| **Module 2** | Orchestration (Kestra / Mage / Airflow) | DAGs, scheduling, backfills, triggers, dependencies | "I orchestrate batch workflows with automated failure retries, email/Slack alerts, and backfilling capabilities." |
| **Module 3** | Data Warehouse (GCS + BigQuery) | External tables, partitioning, clustering, cost optimization | "I understand BigQuery pricing (slots vs on-demand), query pruning via partitioning, and nested repeated records (`ARRAY`/`STRUCT`)." |
| **Module 4** | Analytics Engineering (dbt) | Staging/Core models, incremental tables, tests, macros | "I don't write ad-hoc SQL views; I manage transformations in code with dbt, implementing CI/CD testing and SCD dimensions." |
| **Module 5** | Batch Processing (Spark / PySpark) | Distributed computing, RDD vs DataFrame, DAG shuffles, Dataproc | "I understand how distributed jobs execute, why wide transformations cause shuffles, and how broadcast joins optimize lookups." |
| **Module 6** | Streaming (Kafka) | Topics, partitions, producer/consumer, consumer groups, lag | "I design event-driven streaming architectures capable of handling real-time events with idempotent consumers." |
| **Project** | End-to-End Capstone | Combining all modules into a live GitHub repo | **Your flagship resume project that proves hands-on mastery.** |

---

## Part 4: Our Step-by-Step Learning Gameplan

Whenever you are working through Zoomcamp, I am here as your personal Senior Data Engineering mentor.

1. **Stuck on Docker / Postgres / Networking?**
   - Bring me your `docker-compose.yml`, network errors, or connection string issues. We'll solve them and explain *why* the fix worked.
2. **Mastering the SQL & Data Ingestion (NY Taxi)?**
   - We will write the ingestion script together using Python generators and `chunksize` to show how production-grade batching works.
3. **Module Transition Reviews:**
   - After each module, we will do a **10-minute quiz** covering the exact interview questions asked about that tool.
