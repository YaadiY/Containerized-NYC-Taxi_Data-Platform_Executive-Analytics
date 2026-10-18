-- Explore typical values and extremes in the January clean table.
-- Exact percentiles sort millions of values and may take a while.
SELECT
    COUNT(*) AS total_rows,
    Round(MIN(trip_distance)::numeric,2) AS min_distance_miles,
    Round(AVG(trip_distance)::numeric,2) AS avg_distance_miles,
	percentile_cont(ARRAY[0.5, 0.95, 0.99, 0.999]) WITHIN GROUP (ORDER BY trip_distance),
    ---percentile_cont(0.50) WITHIN GROUP (ORDER BY trip_distance) AS median_distance_miles,
    ---percentile_cont(0.95) WITHIN GROUP (ORDER BY trip_distance) AS p95_distance_miles,
    ---percentile_cont(0.99) WITHIN GROUP (ORDER BY trip_distance) AS p99_distance_miles,
    ---percentile_cont(0.999) WITHIN GROUP (ORDER BY trip_distance) AS p999_distance_miles,
    MAX(trip_distance) AS max_distance_miles,
    MIN(trip_duration_minutes) AS min_duration_minutes,
    AVG(trip_duration_minutes) AS avg_duration_minutes,
	percentile_cont(ARRAY[0.5, 0.95, 0.99, 0.999]) WITHIN GROUP (ORDER BY trip_duration_minutes),
    ---percentile_cont(0.50) WITHIN GROUP (ORDER BY trip_duration_minutes) AS median_duration_minutes,
    ---percentile_cont(0.95) WITHIN GROUP (ORDER BY trip_duration_minutes) AS p95_duration_minutes,
    ---percentile_cont(0.99) WITHIN GROUP (ORDER BY trip_duration_minutes) AS p99_duration_minutes,
    ---percentile_cont(0.999) WITHIN GROUP (ORDER BY trip_duration_minutes) AS p999_duration_minutes,
    MAX(trip_duration_minutes) AS max_duration_minutes,
    MIN(total_amount) AS min_total_amount,
    AVG(total_amount) AS avg_total_amount,
	percentile_cont(ARRAY[0.5, 0.95, 0.99, 0.999]) WITHIN GROUP (ORDER BY trip_duration_minutes),
    ---percentile_cont(0.50) WITHIN GROUP (ORDER BY total_amount) AS median_total_amount,
    ---percentile_cont(0.95) WITHIN GROUP (ORDER BY total_amount) AS p95_total_amount,
    ---percentile_cont(0.99) WITHIN GROUP (ORDER BY total_amount) AS p99_total_amount,
    ---percentile_cont(0.999) WITHIN GROUP (ORDER BY total_amount) AS p999_total_amount,
    MAX(total_amount) AS max_total_amount
FROM yellow_taxi_trips_2025_01_clean;


-- Calculate the distance IQR fence. This is a statistical review threshold,
-- not a universal rule that says every row beyond the fence is invalid.
WITH quartiles AS (
    SELECT
        percentile_cont(0.25) WITHIN GROUP (ORDER BY trip_distance) AS q1,
        percentile_cont(0.75) WITHIN GROUP (ORDER BY trip_distance) AS q3
    FROM yellow_taxi_trips_2025_01_clean
    WHERE trip_distance > 0
)
SELECT
    q1,
    q3,
    q3 - q1 AS interquartile_range,
    q3 + 1.5 * (q3 - q1) AS upper_review_fence
FROM quartiles;

-- List trips above the calculated distance IQR fence for manual review.
WITH quartiles AS (
    SELECT
        percentile_cont(0.25) WITHIN GROUP (ORDER BY trip_distance) AS q1,
        percentile_cont(0.75) WITHIN GROUP (ORDER BY trip_distance) AS q3
    FROM yellow_taxi_trips_2025_01_clean
    WHERE trip_distance > 0
), bounds AS (
    SELECT q3 + 1.5 * (q3 - q1) AS upper_review_fence
    FROM quartiles
)
SELECT
    trips.tpep_pickup_datetime,
    trips.tpep_dropoff_datetime,
    trips.trip_duration_minutes,
    trips.trip_distance,
    trips.fare_amount,
    trips.total_amount,
    trips.passenger_count,
    trips."PULocationID",
    trips."DOLocationID",
    bounds.upper_review_fence
FROM yellow_taxi_trips_2025_01_clean AS trips
CROSS JOIN bounds
WHERE trips.trip_distance > bounds.upper_review_fence
ORDER BY trips.trip_distance DESC
LIMIT 100;

-- Inspect the 50 longest-distance trips for source and business review.
SELECT
    tpep_pickup_datetime,
    tpep_dropoff_datetime,
    trip_duration_minutes,
    trip_distance,
    fare_amount,
    total_amount,
    passenger_count,
    "PULocationID",
    "DOLocationID"
FROM yellow_taxi_trips_2025_01_clean
ORDER BY trip_distance DESC NULLS LAST
LIMIT 50;

-- Show a coarse distance distribution in 5-mile buckets from 0 to 60+ miles.
SELECT
    width_bucket(trip_distance, 0, 60, 12) AS bucket_number,
    COUNT(*) AS trip_count
FROM yellow_taxi_trips_2025_01_clean
WHERE trip_distance >= 0
GROUP BY bucket_number
ORDER BY bucket_number;
