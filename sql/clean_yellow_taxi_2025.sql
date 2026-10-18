-- Build a curated January 2025 table while preserving the ingested source table.
-- Re-running this script replaces only the derived clean table.
-- Drop the prior derived table so the transformation can be rerun from scratch.
DROP TABLE IF EXISTS yellow_taxi_trips_2025_01_clean;

-- Create the curated table from the ingested trip rows and zone lookup.
CREATE TABLE yellow_taxi_trips_2025_01_clean AS
SELECT
    -- Keep every original trip column for later analysis and traceability.
    trips.*,
    -- Add the pickup calendar date for daily and monthly aggregations.
    trips.tpep_pickup_datetime::date AS pickup_date,
    -- Calculate trip duration in minutes, rounded to two decimal places.
    ROUND(
        -- Convert the time difference from seconds to minutes.
        (EXTRACT(EPOCH FROM (trips.tpep_dropoff_datetime - trips.tpep_pickup_datetime)) / 60)::numeric,
        2
    ) AS trip_duration_minutes,
    -- Add the pickup borough from the taxi-zone lookup table.
    pickup_zone."Borough" AS pickup_borough,
    -- Add the pickup zone name from the taxi-zone lookup table.
    pickup_zone."Zone" AS pickup_zone,
    -- Add the dropoff borough from the taxi-zone lookup table.
    dropoff_zone."Borough" AS dropoff_borough,
    -- Add the dropoff zone name from the taxi-zone lookup table.
    dropoff_zone."Zone" AS dropoff_zone
-- Read trips from the original ingested table.
FROM yellow_taxi_trips_2025_01 AS trips
-- Match each pickup location to its borough and zone name.
LEFT JOIN zones AS pickup_zone
    -- The trip's pickup location ID matches the lookup's location ID.
    ON trips."PULocationID" = pickup_zone."LocationID"
-- Match each dropoff location to its borough and zone name.
LEFT JOIN zones AS dropoff_zone
    -- The trip's dropoff location ID matches the lookup's location ID.
    ON trips."DOLocationID" = dropoff_zone."LocationID"
-- Keep only trips whose pickup timestamp falls within January 2025.
WHERE trips.tpep_pickup_datetime >= TIMESTAMP '2025-01-01'
  -- Use an exclusive upper bound so all times on January 31 are included.
  AND trips.tpep_pickup_datetime < TIMESTAMP '2025-02-01'
  -- Exclude records without a dropoff timestamp.
  AND trips.tpep_dropoff_datetime IS NOT NULL
  -- Exclude trips whose dropoff happened before pickup.
  AND trips.tpep_dropoff_datetime >= trips.tpep_pickup_datetime
  -- Exclude records without a trip distance.
  AND trips.trip_distance IS NOT NULL
  -- Exclude negative distances while allowing zero-distance records for review.
  AND trips.trip_distance >= 0;

-- Add an index on pickup date to speed up date-based filters and aggregations.
CREATE INDEX idx_yellow_taxi_2025_01_clean_pickup_date
    ON yellow_taxi_trips_2025_01_clean (pickup_date);

-- Refresh PostgreSQL's table statistics so its query planner can choose plans using the new data.
ANALYZE yellow_taxi_trips_2025_01_clean;
