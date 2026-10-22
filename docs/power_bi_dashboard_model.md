# Power BI Gold Dashboard Model

This guide records the model used by [`Final Dashboard NYC Taxi Data.pbix`](../Final%20Dashboard%20NYC%20Taxi%20Data.pbix). It is a report over the January 2025 Gold aggregate, with shared dimensions and DAX measures so slicers can filter multiple visuals. The original first-chart walkthrough is in [`dashboard_first_chart.md`](dashboard_first_chart.md).

## Source and Grain

The source is `gold_yellow_taxi_daily_demand_2025_01`. One row represents a combination of:

- pickup date;
- pickup borough and zone;
- dropoff borough and zone; and
- payment type.

`trip_count` is the number of cleaned Silver trips represented by that Gold group. It is additive, so use `SUM(trip_count)` for trip totals. The Gold view reconciles to 3,475,080 January Silver rows across 463,623 Gold groups.

The Gold view contains borough and zone labels but does not retain `PULocationID` or `DOLocationID`. The TLC `zones` lookup has duplicate label pairs: Manhattan's Governor's Island/Ellis Island/Liberty Island label maps to IDs 103, 104, and 105, and Queens' Corona label maps to IDs 56 and 57. A Power Query merge from this Gold data to `zones` on borough and zone can multiply fact rows. A Jan 1 report total of 90,303 was found after the name-based merges; the Gold SQL total is 90,186.

For this aggregate report, use distinct borough/zone pairs as dimensions with composite keys. Do not assign an arbitrary taxi-zone ID to an aggregated name pair. For true ID-level analysis, use the separate trip-level PostgreSQL star schema, which retains source IDs: [`../sql/star_schema_yellow_taxi_2025_01.sql`](../sql/star_schema_yellow_taxi_2025_01.sql).

## Tables and Relationships

- **Fact_Gold_Yellow_Taxi_2025_01**: imported Gold measures and descriptive fields, including `trip_count`, `trips_with_review_flags`, `pickup_date`, and the cleaned pickup/dropoff borough and zone labels.
- **DimDate**: one row per calendar date, with `Date`, `Weekday`, and `Weekday Number` columns.
- **DimPickupLocation**: one row per distinct pickup borough/zone pair from the fact.
- **DimDropoffLocation**: one row per distinct dropoff borough/zone pair from the fact.
- **Measure**: a disconnected home table for measures. Its placeholder `Column` can be hidden.

Create a many-to-one relationship from each dimension to the fact, with single-direction filtering from dimension to fact:

| Dimension key | Fact key |
| --- | --- |
| `DimDate[Date]` | `Fact_Gold_Yellow_Taxi_2025_01[pickup_date]` |
| `DimPickupLocation[PickupLocationKey]` | `Fact_Gold_Yellow_Taxi_2025_01[PickupLocationKey]` |
| `DimDropoffLocation[DropoffLocationKey]` | `Fact_Gold_Yellow_Taxi_2025_01[DropoffLocationKey]` |

Construct pickup and dropoff keys consistently in the fact and corresponding dimension. For example, concatenate normalized borough and zone labels with a separator, converting nulls to the same explicit label on both sides. Build the dimensions from the fact's distinct key and label pairs. That guarantees one dimension row for every Gold pair and avoids ambiguous lookup matches.

Use `DimPickupLocation[Borough]` for the pickup-borough slicer. Use fields from the dimensions in chart axes and legends; use measures from `Measure` in Values. Old SQL-import tables such as Query1–Query5 are disconnected and should not drive visuals intended to respond to the shared slicers. Remove or hide those tables after confirming no visual depends on them.

## DAX Measures

Create these with **Modeling → New measure**. Replace table or column names if the Fields pane uses different names.

```DAX
Total Trips =
SUM('Fact_Gold_Yellow_Taxi_2025_01'[trip_count])

Trips With Review Flags =
SUM('Fact_Gold_Yellow_Taxi_2025_01'[trips_with_review_flags])

Pct Trips With Review Flags =
DIVIDE([Trips With Review Flags], [Total Trips])

Average Daily Trips =
AVERAGEX(
    VALUES('DimDate'[Date]),
    [Total Trips]
)

Days in January =
DISTINCTCOUNT('DimDate'[Date])

Pct of Selected Borough Pickups =
DIVIDE(
    [Total Trips],
    CALCULATE(
        [Total Trips],
        REMOVEFILTERS('DimPickupLocation'[Zone])
    )
)
```

Format the two percentage measures as **Percentage** in Power BI; the formulas return a decimal ratio. `Days in January` is appropriate while the report is limited to January 2025. For a multi-month report, rename it to `Days in Period` or define the intended date window explicitly.

## Visual Field Map

| Visual | Fields |
| --- | --- |
| Daily trips trend | `DimDate[Date]` on X-axis; `[Total Trips]` on Y-axis. Use the raw Date column, not the automatic Date hierarchy. |
| Daily quality trend | `DimDate[Date]` on X-axis; `[Pct Trips With Review Flags]` on Y-axis; `[Trips With Review Flags]` and `[Total Trips]` in Tooltips. |
| Pickup-zone ranking | `DimPickupLocation[Zone]` as category; `[Total Trips]` as value; `[Pct of Selected Borough Pickups]` in Tooltips. Apply a visual Top N filter by `[Total Trips]`. The borough slicer can scope the ranking; add a visual Borough = Manhattan filter if the chart should always be Manhattan-specific. |
| Weekday demand by borough | `DimDate[Weekday]` on X-axis; `[Average Daily Trips]` as the only value; `DimPickupLocation[Borough]` as legend; `[Days in January]` in Tooltips. Sort `Weekday` by `Weekday Number` and sort the visual ascending. |
| KPI cards | `[Total Trips]` and `[Average Daily Trips]`. Both respond to date and borough slicers. |

The visual-level `Top N` filter limits displayed zones; the percentage measure removes the zone category filter from its denominator while retaining the selected borough and other report filters.

## Slicers and Date Axes

- Pickup borough slicer: use `DimPickupLocation[Borough]` so it filters the fact and connected visuals.
- Weekday slicer: use `DimDate[Weekday]` alone if the intent is to select weekdays.
- Day-of-month slider: use `DimDate[Day of Month]` only if selecting day numbers (1–31) across the selected month is intended.
- Date-range slicer: use the raw `DimDate[Date]` field and set the slicer type to **Between**.
- For daily charts, inspect the X-axis field well and choose `Date`, not **Date hierarchy**. If the axis shows only `2025`, it is grouped at the Year level; switch to the raw Date column.
- Weekdays should run Monday to Sunday. In Report view, select `DimDate[Weekday]`, then choose **Column tools → Sort by column → Weekday Number**. Sort the chart axis ascending afterward.
- A click on a chart data point cross-filters other visuals. Clear the selection by clicking the selected point again or empty chart space. **Clear all slicers** resets slicers, not necessarily a selected chart point.

## Reconciliation and Current State

The database check for Jan 1 is:

```sql
SELECT
    pickup_date,
    SUM(trip_count) AS total_trips
FROM gold_yellow_taxi_daily_demand_2025_01
WHERE pickup_date = DATE '2025-01-01'
GROUP BY pickup_date;
```

It returns 90,186. After removing the ambiguous name-to-ID merges and using pair keys, the Power BI report showed 90.186K for Jan 1, matching the SQL result. With the weekday slicer set to Wednesday and day-of-month set to 1, both KPI cards show that one-day total; this is expected because only one date remains in filter context.

The last reviewed screenshot still showed the daily chart X-axis at `2025`, indicating a Year hierarchy level. Before presenting the full-month report, change both daily trend charts to raw `DimDate[Date]`, clear slicers and chart selections, and verify the monthly total against 3,475,080 and the average against about 112,099 trips per day.

## Interpretation Notes

- Review flags are provisional investigation signals, not proof that a trip is invalid.
- `Unknown` and `Unknown / unmapped` are different labels and should remain distinct unless a reporting rule says otherwise.
- The report uses Gold trip counts and quality counts. It does not calculate revenue; negative fares and Flex Fare behavior remain under investigation.
- The report is an Import-mode local Power BI file connected to PostgreSQL. Refreshing it requires the database to be available; imported rows are stored in the PBIX between refreshes.
