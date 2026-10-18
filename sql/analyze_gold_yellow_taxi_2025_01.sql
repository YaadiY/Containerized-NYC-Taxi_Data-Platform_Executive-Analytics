-- Read-only analyses for the January 2025 Gold daily-demand view.
-- Run the Gold model first if gold_yellow_taxi_daily_demand_2025_01 does not exist.

-- 1. Total cleaned trips by pickup date.
-- Summing trip_count collapses the finer Gold groups into one number per day.
SELECT
    pickup_date,
    SUM(trip_count) AS total_trips
FROM gold_yellow_taxi_daily_demand_2025_01
GROUP BY pickup_date
ORDER BY pickup_date;

-- 2. Average daily trip total by weekday.
-- First aggregate to one row per date, then average those daily totals.
WITH daily_totals AS (
    SELECT
        pickup_date,
        SUM(trip_count) AS total_trips
    FROM gold_yellow_taxi_daily_demand_2025_01
    GROUP BY pickup_date
)
SELECT
    EXTRACT(ISODOW FROM pickup_date)::integer AS weekday_number,
    TO_CHAR(pickup_date, 'FMDay') AS weekday,
    ROUND(AVG(total_trips), 0) AS average_daily_trips,
    MIN(total_trips) AS lowest_day,
    MAX(total_trips) AS highest_day,
    COUNT(*) AS days_in_january
FROM daily_totals
GROUP BY 1, 2
ORDER BY 1;

-- 3. Average daily trips by pickup borough and weekday.
-- Each date/borough is totaled first so the final average is at the daily grain.
-- NULL boroughs are retained and labeled as unknown/unmapped in the output.
WITH daily_borough AS (
    SELECT
        pickup_date,
        pickup_borough,
        SUM(trip_count) AS total_trips
    FROM gold_yellow_taxi_daily_demand_2025_01
    GROUP BY pickup_date, pickup_borough
)
SELECT
    EXTRACT(ISODOW FROM pickup_date)::integer AS weekday_number,
    TO_CHAR(pickup_date, 'FMDay') AS weekday,
    COALESCE(pickup_borough, 'Unknown / unmapped') AS pickup_borough,
    ROUND(AVG(total_trips), 0) AS average_daily_trips,
    COUNT(*) AS days_in_january
FROM daily_borough
GROUP BY 1, 2, 3
ORDER BY 1, 3;

-- 4. Ten busiest Manhattan pickup zones for the month.
-- Summing trip_count collapses dates, dropoff zones, and payment types.
WITH manhattan_zone_totals AS (
    SELECT
        pickup_zone,
        SUM(trip_count) AS total_trips
    FROM gold_yellow_taxi_daily_demand_2025_01
    WHERE pickup_borough = 'Manhattan'
    GROUP BY pickup_zone
)
SELECT
    pickup_zone,
    total_trips,
    ROUND(100.0 * total_trips / SUM(total_trips) OVER (), 2) AS pct_of_manhattan_pickups
FROM manhattan_zone_totals
ORDER BY total_trips DESC
LIMIT 10;

-- 5. Ten most common dropoff zones for trips picked up in Midtown Center.
-- The percentage denominator is all trips whose pickup zone is Midtown Center.
WITH midtown_center_destinations AS (
    SELECT
        dropoff_borough,
        dropoff_zone,
        SUM(trip_count) AS total_trips
    FROM gold_yellow_taxi_daily_demand_2025_01
    WHERE pickup_borough = 'Manhattan'
      AND pickup_zone = 'Midtown Center'
    GROUP BY dropoff_borough, dropoff_zone
)
SELECT
    dropoff_borough,
    dropoff_zone,
    total_trips,
    ROUND(100.0 * total_trips / SUM(total_trips) OVER (), 2) AS pct_of_midtown_center_pickups
FROM midtown_center_destinations
ORDER BY total_trips DESC
LIMIT 10;

-- 6. Full dropoff-borough distribution for trips picked up in Midtown Center.
-- Unlike query 5, this includes every destination borough, not just the top zones.
WITH midtown_center_dropoff_boroughs AS (
    SELECT
        COALESCE(dropoff_borough, 'Unknown / unmapped') AS dropoff_borough,
        SUM(trip_count) AS total_trips
    FROM gold_yellow_taxi_daily_demand_2025_01
    WHERE pickup_borough = 'Manhattan'
      AND pickup_zone = 'Midtown Center'
    GROUP BY COALESCE(dropoff_borough, 'Unknown / unmapped')
)
SELECT
    dropoff_borough,
    total_trips,
    ROUND(100.0 * total_trips / SUM(total_trips) OVER (), 2) AS pct_of_midtown_center_pickups
FROM midtown_center_dropoff_boroughs
ORDER BY total_trips DESC;

-- 7. Manhattan destination share by weekday for Midtown Center pickups.
-- The percentage is trip-weighted within each weekday, not an average of daily percentages.
SELECT
    EXTRACT(ISODOW FROM pickup_date)::integer AS weekday_number,
    TO_CHAR(pickup_date, 'FMDay') AS weekday,
    COUNT(DISTINCT pickup_date) AS observed_dates,
    SUM(trip_count) AS total_pickups,
    SUM(trip_count) FILTER (WHERE dropoff_borough = 'Manhattan') AS manhattan_dropoffs,
    ROUND(
        100.0 * SUM(trip_count) FILTER (WHERE dropoff_borough = 'Manhattan')
        / SUM(trip_count),
        2
    ) AS pct_dropped_off_in_manhattan
FROM gold_yellow_taxi_daily_demand_2025_01
WHERE pickup_borough = 'Manhattan'
  AND pickup_zone = 'Midtown Center'
GROUP BY 1, 2
ORDER BY 1;

-- 8. Daily percentage of trips with one or more provisional review flags.
-- trips_with_review_flags counts each flagged trip once, even if it has several flags.
SELECT
    pickup_date,
    SUM(trip_count) AS total_trips,
    SUM(trips_with_review_flags) AS trips_with_review_flags,
    ROUND(
        100.0 * SUM(trips_with_review_flags) / NULLIF(SUM(trip_count), 0),
        2
    ) AS pct_trips_with_review_flags
FROM gold_yellow_taxi_daily_demand_2025_01
GROUP BY pickup_date
ORDER BY pickup_date;
