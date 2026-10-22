# First Dashboard Chart: Daily Taxi Demand

This page is the original walkthrough for importing individual SQL result sets. The current slicer-driven report uses a shared fact/dimension model and measures; see the [Power BI model and dashboard guide](power_bi_dashboard_model.md) for that setup and the final validation notes.

This walkthrough connects Power BI Desktop to the local PostgreSQL database and builds a line chart from the Gold daily-demand view.

## Before You Start

- Start the PostgreSQL service with `docker compose up -d`.
- Confirm `gold_yellow_taxi_daily_demand_2025_01` exists by running the Gold SQL model in pgAdmin if needed.
- Use the PostgreSQL database credentials configured in `docker-compose.yaml`. These are separate from the pgAdmin web-login credentials.

## Connect Power BI to PostgreSQL

1. In Power BI Desktop, choose **Home > Get data > PostgreSQL database**.
2. Enter `localhost:5432` as the server and `ny_taxi` as the database.
3. Choose **Import** for this introductory report.
4. Under **Advanced options**, enter this SQL statement:

   ```sql
   SELECT
       pickup_date,
       SUM(trip_count) AS total_trips
   FROM gold_yellow_taxi_daily_demand_2025_01
   GROUP BY pickup_date
   ORDER BY pickup_date;
   ```

5. Select **OK**, authenticate with the PostgreSQL credentials, review the preview, and load the result.

The PostgreSQL connector in Power BI Desktop supports Import and a native SQL statement through its advanced options. See Microsoft's [PostgreSQL connector documentation](https://learn.microsoft.com/power-query/connectors/postgresql).

## Build the Line Chart

1. Add a **Line chart** visual to the report canvas.
2. Put `pickup_date` on the X-axis. If Power BI creates a date hierarchy, use the date field itself rather than Year/Quarter/Month/Day levels.
3. Put `total_trips` on the Y-axis.
4. Sort `pickup_date` in ascending order.
5. Set the chart title to **Daily Yellow Taxi Trips — January 2025**.
6. Save the report as `yellow_taxi_january_2025.pbix`.

## What the Chart Means

Each point is the number of trips in the cleaned January dataset by pickup date. The query sums the Gold view's `trip_count` across zones and payment types. The daily counts reconcile to 3,475,080 trips for the month. This chart shows daily volume; it does not explain what caused the changes, and it excludes records filtered out when the Silver table was built.

## Add a Pickup-Zone Ranking Chart

This second visual highlights where Manhattan pickups are concentrated.

1. In Power BI, choose **Home > Get data > PostgreSQL database** again, using the same server, database, and Import mode.
2. Under **Advanced options**, enter:

   ```sql
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
   ```

3. Load this result as a separate table in the report.
4. Add a **Clustered bar chart** (the horizontal bar visual), not a combo chart. Put `pickup_zone` on the Y-axis and `total_trips` on the X-axis/Values field.
5. Keep `pct_of_manhattan_pickups` out of the chart's Values field; add it to Tooltips if desired. Sort by `total_trips` descending and turn on data labels.
6. Title it **Top 10 Manhattan Pickup Zones — January 2025**.

These are the ten busiest pickup zones within Manhattan. Their percentages use all Manhattan pickups as the denominator; they are not percentages of all NYC trips.

**Check the field source:** `pickup_zone`, `total_trips`, and `pct_of_manhattan_pickups` must all come from the table imported from this same top-zone query. If every zone bar repeats the full-month total (about 3.48 million), the category and value are likely coming from separate, unrelated imported query tables. Remove those fields and add both `pickup_zone` and `total_trips` from the top-zone result table; add its percentage from that same table to Tooltips. The expected zone totals range from about 95,000 to 170,000, with Midtown Center at 169,977.

## Add Two KPI Cards

Use the daily totals table from the first chart. The table has one row per pickup date, so `SUM(total_trips)` is the January total and `AVERAGE(total_trips)` is the average daily volume.

1. Add a **Card** visual and add `total_trips` to its Values field.
2. Set its aggregation to **Sum** and title it **January Trips**. It should show 3,475,080 (or about 3.48M if display units are abbreviated).
3. Add another **Card** visual with `total_trips`, but set the aggregation to **Average**. Title it **Average Trips per Day**; it should show about 112,099.
4. Place the cards above the line chart and zone chart as a compact summary row.

Power BI's Card visual displays measures or data columns in the Values field; see Microsoft's [Card visual guide](https://learn.microsoft.com/power-bi/visuals/power-bi-visualization-card).

## Add a Weekday-by-Borough Chart

Query 3 in [`../sql/analyze_gold_yellow_taxi_2025_01.sql`](../sql/analyze_gold_yellow_taxi_2025_01.sql) returns average daily trips by weekday and pickup borough. It totals each date/borough first, then averages the daily totals, so weekdays with five dates are comparable to weekdays with four dates.

1. Import query 3 as another table in Power BI, using the same PostgreSQL connection and Import mode.
2. Add a **Clustered column chart**. Put `weekday` on the X-axis, `average_daily_trips` in the Y-axis/Values field, and `pickup_borough` in the Legend. Set the aggregation for `average_daily_trips` to **Average**; there is one row for each weekday/borough combination, so this preserves the SQL result and labels the metric clearly.
3. Sort `weekday` by `weekday_number` so it runs Monday through Sunday. In Report view, select the `weekday` column from this table in the Data pane, then choose **Column tools > Sort by column > weekday_number**. Both columns must be in the same table.
4. Add a **Slicer** using `pickup_borough` from this imported table. Select one borough at a time to compare its weekday pattern.
5. Add `days_in_january` to Tooltips so a viewer can see how many dates contribute to each average. Make sure it is not in the Y-axis/Values field; otherwise Power BI plots it as a second, unrelated measure.

Manhattan has far more trips than the other boroughs, so its bars can make the smaller boroughs hard to compare when all boroughs are displayed together. Use the borough slicer to inspect them individually. The `Unknown` and `Unknown / unmapped` categories represent different data states and should not be combined without an explicit reporting rule.

## Add a Daily Data-Quality Trend

Query 8 in [`../sql/analyze_gold_yellow_taxi_2025_01.sql`](../sql/analyze_gold_yellow_taxi_2025_01.sql) returns daily trip totals and the percentage of trips with at least one provisional review flag.

1. Import query 8 as another table.
2. Add a **Line chart** with `pickup_date` on the X-axis and `pct_trips_with_review_flags` on the Y-axis.
3. Put `trips_with_review_flags` and `total_trips` in Tooltips for context.
4. Title it **Share of Trips Flagged for Review — January 2025**.

The percentage counts each trip once if any review condition applies, even if several flags apply to that trip. The flags are triage signals, not proof that a trip is invalid. Overall, the month has 635,315 flagged trips out of 3,475,080 cleaned trips (about 18.3%).

## Visual Field Checklist

If a chart title shows multiple measures, check that tooltip-only fields have not also been added to its axis/Values:

- Daily trips line chart: X-axis is the `pickup_date` column itself, not its **Date hierarchy > Day** level; Y-axis is `total_trips`.
- Manhattan zone bar chart: Values contains `total_trips`; `pct_of_manhattan_pickups` belongs in Tooltips.
- Weekday/borough chart: Values contains `average_daily_trips`; `days_in_january` belongs in Tooltips. Use the borough slicer because Manhattan's scale is much larger.
- Quality trend: X-axis is the `pickup_date` column itself; Y-axis contains only `pct_trips_with_review_flags`. Move trip counts to Tooltips.
- Delete any unused blank visual from the canvas.

For a date axis, use the column name from the field dropdown instead of **Date hierarchy**. Power BI creates a hierarchy with a Day level when a date is placed on an axis; that can display day numbers instead of full dates. Don't try to uncheck the hierarchy in the Data pane: checking the date field there is what adds the default hierarchy. In the X-axis field well, open the field menu and choose the raw `pickup_date` column. If the raw-column option isn't available, remove the date field from the axis, drag `pickup_date` back from the Data pane, and choose the column rather than **Date hierarchy** when prompted. See Microsoft's [X-axis guidance](https://learn.microsoft.com/power-bi/visuals/power-bi-visualization-customize-x-axis-and-y-axis).
