# SQL Study Notes for Analytics Engineering

SQL is the language used to read, validate, transform, and model relational data. In this project, PostgreSQL executes the cleaning, profiling, flagging, and reporting queries.

## Query Building Blocks

    SELECT pickup_date, COUNT(*) AS trip_count
    FROM yellow_taxi_trips_2025_01_clean
    WHERE pickup_date >= DATE '2025-01-01'
      AND pickup_date < DATE '2025-02-01'
    GROUP BY pickup_date
    HAVING COUNT(*) > 100
    ORDER BY pickup_date;

- WHERE filters source rows before aggregation.
- GROUP BY defines the output grain.
- HAVING filters groups after aggregation.
- ORDER BY sorts the final result.
- COUNT(*) counts rows; COUNT(column) ignores NULL in that column.
- FILTER (WHERE ...) computes conditional aggregates, such as flagged-row counts.

## Joins and Grain

A join combines rows based on keys. Always check whether the lookup key is unique: a many-to-many or duplicate lookup join can multiply facts and inflate totals. The taxi cleaning SQL uses left joins to zones, preserving trips whose zone lookup is missing. Use LEFT JOIN when unmatched source rows should remain visible; use INNER JOIN only when unmatched rows should be excluded by the business rule.

Before writing an aggregate, say its grain aloud. Example: one output row per pickup_date x pickup_zone x payment_type. Every selected non-aggregated column must be represented in that grain.

## NULL, CASE, and Identifiers

- NULL means unknown or absent, not zero. Use IS NULL/IS NOT NULL; = NULL does not work.
- COALESCE(value, 0) supplies a fallback for calculations, but do not use it to erase the meaning of missing data in reporting.
- Use CASE to map codes into readable labels.
- PostgreSQL folds unquoted identifiers to lowercase. A source column named "Airport_fee" must be double-quoted exactly; string values use single quotes.

## CTEs and Window Functions

CTEs (WITH ... AS (...)) name intermediate result sets and make multi-stage SQL easier to review. A window function calculates across related rows without collapsing them. Practice ROW_NUMBER, RANK, LAG, LEAD, running totals, and partitioned averages. Use ROW_NUMBER for deterministic selection only when the ORDER BY fully resolves ties.

## Performance Checklist

1. Select only needed columns and filter to the relevant date range.
2. Check join cardinality and table statistics.
3. Use EXPLAIN for a planned query; EXPLAIN ANALYZE actually runs it and can be expensive on large data.
4. Index columns used often in selective filters or joins, but remember indexes cost storage and slow writes.
5. Prefer range predicates on timestamps/dates over applying a function to every row when that would prevent use of an index.
6. Compare query results with an independent count or known source total.

## Interview Questions

1. WHERE vs HAVING? WHERE filters rows before grouping; HAVING filters aggregated groups.
2. COUNT(*) vs COUNT(col)? The former counts rows; the latter skips rows where col is NULL.
3. Why can a join inflate a sum? The join key may match multiple lookup rows, duplicating fact rows before aggregation.
4. What does a window function add? Calculations over a partition while preserving individual rows, unlike a grouped aggregate.
5. How would you investigate an outlier? Profile its distribution, inspect representative rows and related dimensions, compare against domain rules, then flag or reject only with a documented reason.

## Exercises

- Count January trips by pickup date and payment type.
- Find the top five pickup zones by trip count, and explain the output grain.
- Compare trip counts before and after joining zones to detect row multiplication.
- Calculate daily negative-fare counts without filtering those records out.
