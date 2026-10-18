# Data Modeling and Quality Notes

## Model from the Grain

Grain is the exact meaning of one row in a fact table or reporting dataset. State it before choosing keys or measures.

Example: one row in the proposed trip fact represents one source trip record. A daily aggregate could instead have grain one row per pickup date, pickup zone, dropoff zone, and payment type. Those are different models.

- Fact table: measurable events or snapshots, with foreign keys to dimensions and numeric measures.
- Dimension: descriptive context for filtering/grouping, such as date, zone, or payment type.
- Surrogate key: generated warehouse key. The taxi source has no declared trip primary key, so profile duplicates and define source-row identity before claiming a durable trip key.
- Degenerate dimension: business identifier retained in a fact when a separate dimension is not useful.
- Conformed dimension: shared definition used by more than one fact/product.

## Slowly Changing Dimensions

- Type 1: overwrite an attribute; history is not retained.
- Type 2: insert a new dimension version with validity dates and a current-row indicator; supports historical as-of joins.
- Type 3: keep a limited previous value in another column.

The taxi zone lookup is reference data. Do not invent Type 2 history unless historical zone attributes or business needs require it.

## Metric Definitions

For each metric document its name, grain, formula, filters, units, NULL handling, timezone, and known exclusions. Example: trip_count could mean all rows in Silver after timestamp/distance rules, including rows carrying review flags. A revenue metric needs a decision about negative fares, negative totals, refunds, and Flex Fare semantics first.

## Data Quality Workflow

1. Profile row counts, date coverage, schema, NULLs, duplicates, distributions, and category values.
2. Define rules from source contracts and business meaning.
3. Separate hard failures from suspicious-but-possible values.
4. Preserve rejected records and reasons in quarantine when practical.
5. Reconcile input, accepted, rejected, and output counts.
6. Monitor rates and distributions by source/provider and time.
7. Document assumptions and limitations; do not convert exploratory thresholds directly into deletion rules.

In this taxi project, the flag view is a review list. The Vendor 2 Flex Fare finding is an unresolved source-data pattern, not a rule to delete all such rows. See the data-quality workflow.

## Interview Questions

1. Why does grain matter? It determines what each row means and prevents double counting or invalid measures.
2. How do you handle an outlier? Profile and investigate it, attach context, then apply a documented business rule; do not delete solely because it is statistically rare.
3. Type 1 vs Type 2 SCD? Type 1 overwrites; Type 2 preserves versions over validity intervals.
4. What is reconciliation? Comparing counts or measures across pipeline boundaries and accounting for accepted/rejected records.
5. What should a metric definition include? Formula, grain, filters, units, NULLs, time rules, and intended interpretation.
