-- Build a Gold reporting view for January 2025 taxi demand.
-- Its grain is one row per pickup date, pickup zone, dropoff zone, and payment type.
-- Review flags remain visible as counts; this view does not remove trips.
-- Revenue totals are intentionally omitted while negative fare semantics are unresolved.
CREATE OR REPLACE VIEW gold_yellow_taxi_daily_demand_2025_01 AS
WITH classified_trips AS (
    -- Read the reusable Silver table and map payment codes to report-friendly labels.
    SELECT
        trips.*,
        CASE
            WHEN trips.payment_type IS NULL THEN 'Missing'
            WHEN trips.payment_type = 0 THEN 'Flex Fare'
            WHEN trips.payment_type = 1 THEN 'Credit card'
            WHEN trips.payment_type = 2 THEN 'Cash'
            WHEN trips.payment_type = 3 THEN 'No charge'
            WHEN trips.payment_type = 4 THEN 'Dispute'
            WHEN trips.payment_type = 5 THEN 'Unknown'
            WHEN trips.payment_type = 6 THEN 'Voided trip'
            ELSE 'Unmapped code'
        END AS payment_type_label,
        -- Count a trip once when any provisional review condition is true.
        CASE
            WHEN trips.trip_duration_minutes = 0
              OR trips.trip_distance = 0
              OR trips.passenger_count IS NULL
              OR trips.fare_amount < 0
              OR trips.total_amount < 0
              OR trips.trip_distance > 200
              OR trips.trip_duration_minutes > 1440
              OR trips.total_amount > 1000
            THEN TRUE
            ELSE FALSE
        END AS has_review_flag
    FROM yellow_taxi_trips_2025_01_clean AS trips
)
-- Aggregate demand and review counts at the declared Gold grain.
SELECT
    pickup_date,
    pickup_borough,
    pickup_zone,
    dropoff_borough,
    dropoff_zone,
    payment_type,
    COUNT(*) AS trip_count,
    COUNT(*) FILTER (WHERE has_review_flag) AS trips_with_review_flags,
    COUNT(*) FILTER (WHERE fare_amount < 0) AS negative_fare_trips,
    COUNT(*) FILTER (WHERE total_amount < 0) AS negative_total_trips,
    -- Append new view columns after the existing public columns for replace compatibility.
    payment_type_label,
    COUNT(*) FILTER (WHERE trip_duration_minutes = 0) AS zero_duration_trips,
    COUNT(*) FILTER (WHERE trip_distance = 0) AS zero_distance_trips,
    COUNT(*) FILTER (WHERE passenger_count IS NULL) AS missing_passenger_count_trips,
    COUNT(*) FILTER (WHERE trip_distance > 200) AS extreme_distance_trips,
    COUNT(*) FILTER (WHERE trip_duration_minutes > 1440) AS extreme_duration_trips,
    COUNT(*) FILTER (WHERE total_amount > 1000) AS extreme_total_trips
FROM classified_trips
GROUP BY
    pickup_date,
    pickup_borough,
    pickup_zone,
    dropoff_borough,
    dropoff_zone,
    payment_type,
    payment_type_label;

-- Validate that grouping preserved every Silver row exactly once.
-- Expected result: source_trip_rows = gold_trip_rows and trip_count_reconciles = TRUE.
SELECT
    (SELECT COUNT(*) FROM yellow_taxi_trips_2025_01_clean) AS source_trip_rows,
    (SELECT COALESCE(SUM(trip_count), 0)
     FROM gold_yellow_taxi_daily_demand_2025_01) AS gold_trip_rows,
    (SELECT COUNT(*) FROM gold_yellow_taxi_daily_demand_2025_01) AS gold_group_rows,
    (SELECT COUNT(*) FROM yellow_taxi_trips_2025_01_clean)
        = (SELECT COALESCE(SUM(trip_count), 0)
           FROM gold_yellow_taxi_daily_demand_2025_01) AS trip_count_reconciles;

-- Validate review-flag and negative-amount totals against the Silver layer.
WITH gold_totals AS (
    SELECT
        COALESCE(SUM(trips_with_review_flags), 0) AS gold_review_flag_rows,
        COALESCE(SUM(negative_fare_trips), 0) AS gold_negative_fare_rows,
        COALESCE(SUM(negative_total_trips), 0) AS gold_negative_total_rows
    FROM gold_yellow_taxi_daily_demand_2025_01
),
silver_totals AS (
    SELECT
        COUNT(*) FILTER (WHERE fare_amount < 0) AS silver_negative_fare_rows,
        COUNT(*) FILTER (WHERE total_amount < 0) AS silver_negative_total_rows
    FROM yellow_taxi_trips_2025_01_clean
),
flagged_total AS (
    SELECT COUNT(*) AS flagged_view_rows
    FROM yellow_taxi_trips_2025_01_flagged
)
SELECT
    gold.gold_review_flag_rows,
    flagged.flagged_view_rows,
    gold.gold_review_flag_rows = flagged.flagged_view_rows AS flag_counts_reconcile,
    gold.gold_negative_fare_rows,
    silver.silver_negative_fare_rows,
    gold.gold_negative_fare_rows = silver.silver_negative_fare_rows
        AS negative_fare_counts_reconcile,
    gold.gold_negative_total_rows,
    silver.silver_negative_total_rows,
    gold.gold_negative_total_rows = silver.silver_negative_total_rows
        AS negative_total_counts_reconcile
FROM gold_totals AS gold
CROSS JOIN silver_totals AS silver
CROSS JOIN flagged_total AS flagged;
