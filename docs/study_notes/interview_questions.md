# Analytics Engineering Interview Practice

Answer from evidence. In this repository, Python batch ingestion, Docker Compose with PostgreSQL/pgAdmin, SQL cleaning/profiling/flags, and a reconciled Gold daily-demand view are implemented. Kafka, a scheduler, Databricks, and a full fact/dimension star schema are not currently implemented.

## Project Walkthrough

**Question: Walk me through this project.**

**Study answer:** “I downloaded NYC TLC trip data and built a chunked Python ingestion path into PostgreSQL. I preserve the raw January table, then use SQL to create a January Silver table with date boundaries, timestamp and distance checks, trip duration, and zone labels. I profile distributions and use a view to flag unusual rows without deleting them. I investigated negative fares in Flex Fare records by provider and date and documented the unresolved pattern. I built a Gold daily-demand view by date, pickup/dropoff zone, and payment type; the grouped trip counts reconcile to the Silver row count. A full star schema and automated orchestration are future work.”

## Technical Questions

1. **What is the grain of your current clean table?** One retained source trip record after the cleaning query's January, timestamp, and distance filters; it does not yet have a declared primary key.
2. **Why preserve the raw table?** To compare source and transformed rows, rerun logic, and investigate quality findings.
3. **What is the difference between a flag and a reject?** A flag identifies a row for review; a reject is excluded by a documented hard rule and should remain traceable with a reason.
4. **How do you prevent duplicate ingestion?** Current append mode does not prevent duplicates. Replace mode is used for a deliberate table rebuild; a production version should add a file manifest/idempotency key and row-count reconciliation.
5. **Why use chunks for ingestion?** To keep memory bounded and send batches to the database rather than materializing the whole file.
6. **What is your current Gold model?** A daily-demand aggregate view, with grain of pickup date, pickup zone, dropoff zone, and payment type. Its trip counts reconcile to Silver. It is not yet a full fact/dimension star schema, and revenue metrics are omitted pending fare-rule decisions.
7. **How did you investigate the Vendor 2 Flex Fare anomaly?** I profiled negative fare/total counts by payment type, provider, day, and hour, then compared total with listed fare components. I retained the records and documented uncertainty instead of deleting a whole category.
8. **Why might a component-sum comparison not prove a Flex Fare record is invalid?** Flex Fare is upfront and non-metered, while fare_amount is a meter-calculated field; interpretation needs source/provider semantics.
9. **How would you tune a slow PostgreSQL query?** Inspect its plan (`EXPLAIN ANALYZE`), filter early, select only needed columns, verify join cardinality, refresh statistics (`ANALYZE`), and add indexes (B-Tree on high-cardinality filters/joins) only where workload evidence supports them.
10. **How did you model the Star Schema and Power BI dashboard?** In PostgreSQL, I built `analytics.dim_date`, `dim_location`, `dim_payment_type`, and `analytics.fact_yellow_taxi_trip_2025_01` with generated surrogate keys. For the Power BI dashboard (`Final Dashboard NYC Taxi Data.pbix`), I modeled the Gold daily-demand aggregate using role-playing pickup/dropoff dimensions, DAX measures for trip trends, and slicers for pickup boroughs.
11. **Why avoid joining TLC Zone lookup by name in Power BI?** The TLC zone lookup table has duplicate borough/zone string combinations across different `LocationID` values. Joining the aggregated Gold view by text name can multiply fact rows. The PostgreSQL trip-level fact table prevents this by preserving and joining on surrogate and source integer `LocationID`s directly.
12. **How do you ensure Git repository hygiene in Data Engineering?** Maintain strict `.gitignore` rules to keep large datasets (`*.parquet`, `*.csv`) and database volumes (`pg_data/`) out of version control, use feature branching with linear rebasing, and validate SQL/Python transformations via automated CI/CD checks before merging.

## Behavioral / Collaboration Questions

1. How do you handle unclear business rules? Make assumptions visible, profile examples, ask the relevant owner, and keep uncertain records flagged until a rule is approved.
2. How do you communicate a data issue? State affected sources and time range, counts/rates, downstream impact, evidence, uncertainty, and proposed owner/action.
3. How do you make work maintainable? Parameterize inputs, keep logic in version control, document data contracts and metrics, add checks, and make reruns safe.

## Personal Answer Checklist

- Can I point to a file, query, or result that proves this claim?
- Did I describe actual scale and measured outcomes accurately?
- Did I distinguish project work from coursework or planned study?
- Can I explain tradeoffs and unresolved assumptions without pretending they are solved?
