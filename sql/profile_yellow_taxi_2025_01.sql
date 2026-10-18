-- Read-only quality profile for the January clean table.
-- Exact percentiles sort millions of values and may take a while.
SELECT
    COUNT(*) AS total_rows,
    COUNT(*) FILTER (WHERE trip_duration_minutes = 0) AS zero_duration_rows,
    COUNT(*) FILTER (WHERE trip_distance = 0) AS zero_distance_rows,
    COUNT(*) FILTER (WHERE fare_amount < 0) AS negative_fare_rows,
    COUNT(*) FILTER (WHERE total_amount < 0) AS negative_total_rows,
    COUNT(*) FILTER (WHERE passenger_count IS NULL) AS missing_passenger_count_rows,
    percentile_cont(ARRAY[0.50, 0.95, 0.99, 0.999])
        WITHIN GROUP (ORDER BY trip_duration_minutes) AS duration_percentiles_minutes,
    percentile_cont(ARRAY[0.50, 0.95, 0.99, 0.999])
        WITHIN GROUP (ORDER BY trip_distance) AS distance_percentiles_miles,
    percentile_cont(ARRAY[0.50, 0.95, 0.99, 0.999])
        WITHIN GROUP (ORDER BY total_amount) AS total_amount_percentiles,
    MAX(trip_duration_minutes) AS maximum_duration_minutes,
    MAX(trip_distance) AS maximum_distance_miles,
    MAX(total_amount) AS maximum_total_amount
FROM yellow_taxi_trips_2025_01_clean;

-- Show the passenger-count values, including NULL, and their frequencies.
SELECT passenger_count, COUNT(*) AS row_count
FROM yellow_taxi_trips_2025_01_clean
GROUP BY passenger_count
ORDER BY passenger_count NULLS FIRST;

-- Compare negative fare/total rows by payment type to identify patterns.
SELECT
    payment_type,
    COUNT(*) FILTER (WHERE fare_amount < 0) AS negative_fare_rows,
    COUNT(*) FILTER (WHERE total_amount < 0) AS negative_total_rows,
    COUNT(*) FILTER (WHERE fare_amount < 0 AND total_amount < 0) AS both_negative_rows,
    MIN(fare_amount) AS minimum_fare,
    MIN(total_amount) AS minimum_total
FROM yellow_taxi_trips_2025_01_clean
WHERE fare_amount < 0 OR total_amount < 0
GROUP BY payment_type
ORDER BY payment_type NULLS FIRST;

-- Inspect the largest distances with their timestamps and amounts.
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
LIMIT 10;

-- Inspect the longest recorded durations.
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
ORDER BY trip_duration_minutes DESC NULLS LAST
LIMIT 10;

-- Inspect the largest total amounts.
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
ORDER BY total_amount DESC NULLS LAST
LIMIT 10;
