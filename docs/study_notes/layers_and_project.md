# Medallion Layers in the Taxi Project

Medallion architecture organizes data by how much it has been validated and shaped for use. Bronze, Silver, and Gold describe data states; they are not specific products or database technologies.

    NYC TLC Parquet and zone CSV
      -> Bronze: local source files
      -> Bronze: raw PostgreSQL tables
      -> Silver: cleaned January trip table
      -> Quality review view and investigations
      -> Gold: validated daily-demand reporting view

## Bronze: Source-Aligned Data

Bronze is the earliest persisted copy of the source. Keep it as close to the source as practical so transformations can be rerun and investigated.

In this repository, local Parquet/CSV files under nyc_taxi_data/ and source tables such as yellow_taxi_trips_2025_01 and zones serve as the Bronze layer. The ingestion script loads batches into PostgreSQL. It does not currently create a formal file manifest, checksum registry, or immutable object-storage landing zone, so those are future hardening steps rather than existing guarantees.

Purpose: traceability, replay, source comparison, and recovery from transformation mistakes.

## Silver: Validated and Consistent Data

Silver is cleaned and standardized enough for reliable reuse, while retaining useful source detail and documented quality signals.

Here, sql/clean_yellow_taxi_2025.sql reads the January raw table and creates yellow_taxi_trips_2025_01_clean. It restricts pickup times to January 2025, requires a non-null dropoff at or after pickup, requires a non-null non-negative distance, calculates pickup date and duration, and adds zone names. It leaves the raw table intact.

Silver does not mean every suspicious value was deleted. The current table retains zero distances, negative fares/totals, missing passenger counts, and extreme values for review. yellow_taxi_trips_2025_01_flagged is a separate non-destructive review view over Silver; it is not a reject table and does not delete rows.

## Gold: Business-Ready Data Products

Gold models answer named reporting or analytics questions. They often contain facts, dimensions, and agreed metric definitions rather than another generic cleaned copy.

For this project, the first product is daily trip demand by pickup date, pickup/dropoff zone, and payment type. The SQL model is in sql/gold_yellow_taxi_daily_demand_2025_01.sql. The local view has 463,623 groups; its trip, review-flag, negative-fare, and negative-total counts reconcile to Silver/review views. This is a Gold aggregate view, not yet a full fact/dimension star schema. Revenue measures are intentionally omitted while negative fare behavior is unresolved.

## Interview Summary

> I land the TLC source files and load raw trip data to PostgreSQL as the Bronze layer. A SQL transformation builds a January Silver table with date boundaries, timestamp and distance checks, derived duration, and zone labels, while preserving the source table. A separate view flags suspicious records for review instead of silently deleting them. I built a Gold daily-demand view at the grain of pickup date, pickup zone, dropoff zone, and payment type; its trip counts reconcile to the Silver row count. The current workflow is manually run; I have not yet added an orchestrator, Kafka, or Databricks, and the Gold model is not yet a full star schema.

## Questions to Practice

1. Why keep Bronze if Silver is cleaner? Bronze lets us replay transformations, compare with the source, and investigate unexpected changes.
2. Does Silver mean every row is valid? No. It means a defined set of cleaning and standardization rules has been applied. Suspicious-but-unresolved records can remain with flags.
3. What is different about Gold? Gold is shaped around business use: a stable grain, conformed dimensions, agreed metrics, and useful documentation.
4. Where do the flags belong? They are quality metadata or a review layer. A flag does not automatically mean a row must be rejected.
5. What would you add next? A full fact/dimension model with agreed metric definitions, then scheduling and deployment hardening.
