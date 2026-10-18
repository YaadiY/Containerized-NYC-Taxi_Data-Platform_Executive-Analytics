-- Create a review view for suspicious January trips without deleting them.
-- The distance, duration, and amount thresholds are provisional review rules.
CREATE OR REPLACE VIEW yellow_taxi_trips_2025_01_flagged AS
SELECT
    trips.*,
    -- Flag trips recorded with no elapsed time.
    trips.trip_duration_minutes = 0 AS flag_zero_duration,
    -- Flag trips recorded with no distance.
    trips.trip_distance = 0 AS flag_zero_distance,
    -- Flag missing passenger counts while preserving them as unknown.
    trips.passenger_count IS NULL AS flag_missing_passenger_count,
    -- Flag negative fares for review; they may be adjustments or corrections.
    trips.fare_amount < 0 AS flag_negative_fare,
    -- Flag negative totals for review; they may be adjustments or corrections.
    trips.total_amount < 0 AS flag_negative_total,
    -- Flag trips above the provisional distance review threshold of 200 miles.
    trips.trip_distance > 200 AS flag_extreme_distance,
    -- Flag trips longer than one day for review (1,440 minutes).
    trips.trip_duration_minutes > 1440 AS flag_extreme_duration,
    -- Flag total amounts above $1,000 for review.
    trips.total_amount > 1000 AS flag_extreme_total
FROM yellow_taxi_trips_2025_01_clean AS trips
WHERE trips.trip_duration_minutes = 0
   OR trips.trip_distance = 0
   OR trips.passenger_count IS NULL
   OR trips.fare_amount < 0
   OR trips.total_amount < 0
   OR trips.trip_distance > 200
   OR trips.trip_duration_minutes > 1440
   OR trips.total_amount > 1000;
