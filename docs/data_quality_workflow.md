# Data Quality and Transformation Workflow

This guide records the current NYC Yellow Taxi data state and the steps used to turn ingested files into analysis-ready data. Row counts below are a database snapshot from **October 17, 2026**; they can change when ingestion or transformation is rerun.

## Current Data Snapshot

| Table / file | Observed state | Notes |
| --- | --- | --- |
| `yellow_taxi_trips_2025` | 700,000 rows; pickup range December 31, 2024 to January 10, 2025 | Partial load; it does not represent all of January or all of 2025. |
| `yellow_taxi_trips_2025_01` | 3,475,226 rows; pickup range December 31, 2024 to February 1, 2025 | Matches the row count in the local `yellow_tripdata_2025-01.parquet` file. The file contains some timestamps outside January. |
| `yellow_taxi_trips_2025_clean` | 699,977 rows; pickup range January 1 to January 10, 2025 | Built from the partial `yellow_taxi_trips_2025` table at the time of the snapshot. It is therefore also partial. |
| `yellow_taxi_trips_2025_01_clean` | 3,475,080 rows; pickup range January 1 to January 31, 2025 | Built from the complete January source on October 17. It retains 1,927 trips with zero-minute duration for review. |
| `yellow_taxi_trips_2025_01_flagged` | View of 635,315 distinct rows | Rows with one or more quality flags; flags overlap and are for review, not automatic rejection. |
| `gold_yellow_taxi_daily_demand_2025_01` | View with 463,623 groups | Daily demand by pickup date, pickup/dropoff zones, and payment type; trip-count sum reconciles to the Silver table. |

The separate January table is already loaded. Avoid appending the same file again: the ingestion command defaults to `append`, which can duplicate rows. If a table needs rebuilding, use `--if_exists replace` with care and target the intended table.

## What the Current SQL Transformation Does

[`../sql/clean_yellow_taxi_2025.sql`](../sql/clean_yellow_taxi_2025.sql) reads `yellow_taxi_trips_2025_01`, preserves that source table, and rebuilds `yellow_taxi_trips_2025_01_clean`. It:

1. Keeps rows whose pickup timestamp falls in January 2025.
2. Requires a dropoff timestamp at or after pickup.
3. Requires a present, non-negative trip distance.
4. Adds the pickup date and trip duration in minutes.
5. Adds pickup and dropoff borough and zone names with left joins to `zones`.
6. Indexes `pickup_date` and refreshes table statistics with `ANALYZE`.

The transformation is an initial set of checks, not a complete quality program. Zero-duration trips are retained; the complete January clean table has 1,927. Outliers such as unusually large fares or distances are not automatically removed because thresholds need to be reviewed against the data and domain.

## January Quality Profile

The read-only queries in [`../sql/profile_yellow_taxi_2025_01.sql`](../sql/profile_yellow_taxi_2025_01.sql) produced this profile for `yellow_taxi_trips_2025_01_clean`:

| Check | Rows / result |
| --- | ---: |
| Zero-minute duration | 1,927 |
| Zero distance | 90,893 |
| Negative fare | 144,118 |
| Negative total amount | 63,037 |
| Missing passenger count | 540,031 |
| Maximum recorded duration | 5,626.32 minutes |
| Maximum recorded distance | 276,423.57 miles |
| Maximum total amount | 863,380.37 |

Median, 95th, 99th, and 99.9th percentiles were 11.7, 36.2, 58.92, and 98.27 minutes for duration; 1.67, 11.83, 19.5, and 28.86 miles for distance; and $19.95, $74.00, $102.92, and $163.98 for total amount.

The maximum distance appeared on a 9-minute trip, and the maximum duration was over 3.9 days. These are strong candidates for anomaly flags or source investigation. Negative fares and totals may represent adjustments, while missing passenger counts mean the value is unknown; keep these categories visible until business rules say how to handle them. The current profile script samples the largest distances, durations, and totals for review.

[`../sql/flag_yellow_taxi_2025_01.sql`](../sql/flag_yellow_taxi_2025_01.sql) creates `yellow_taxi_trips_2025_01_flagged`, a view that marks zero duration, zero distance, missing passenger count, negative fare or total, distance over 200 miles, duration over 24 hours, and total amount over $1,000. The numeric thresholds are provisional triage thresholds informed by the profile; flagged rows remain available and are not deleted. Review samples and domain context before treating any flag as a rejection rule.

The view currently flags 635,315 distinct rows. Counts by flag are not additive because a trip can have several flags. For example, a row may have both a missing passenger count and a negative fare.

### Gold Daily Demand View (October 18, 2026)

[`../sql/gold_yellow_taxi_daily_demand_2025_01.sql`](../sql/gold_yellow_taxi_daily_demand_2025_01.sql) creates `gold_yellow_taxi_daily_demand_2025_01`. Its grain is one row per pickup date, pickup borough/zone, dropoff borough/zone, and payment type. It reports trip counts and overlapping quality counts; `trips_with_review_flags` counts each trip once if any review condition applies. It omits revenue measures while negative fare and Flex Fare semantics remain unresolved.

The local PostgreSQL reconciliation returned 3,475,080 Silver rows, 3,475,080 summed Gold trips, 463,623 Gold groups, and `trip_count_reconciles = TRUE`. Additional checks returned 635,315 Gold rows with review flags, matching the flagged view; 144,118 negative-fare rows and 63,037 negative-total rows, matching Silver. This validates aggregation-count preservation for this view; it does not certify every source value or establish the full dimensional model.

#### First Daily-Demand Read

The first Gold rollup by pickup date returns 3,475,080 trips across the 31 days in January, or about 112,099 trips per day on average. The lowest daily total is 79,623 on January 5; the highest is 138,708 on January 16. A weekday comparison shows the highest average on Thursday (122,842 across five dates) and the lowest on Monday (90,939 across four dates); Tuesday, Wednesday, Friday, and Saturday average roughly 113,000–119,000 trips. The Thursday result includes a low of 84,827 on January 2, while Wednesday includes January 1 at 90,186, so holiday-period days affect these small samples. These are counts from the cleaned January dataset, not a claim that all NYC trips are represented. This is descriptive evidence for one month, not an explanation of the pattern or proof it generalizes.

The corresponding read-only queries are saved in [`../sql/analyze_gold_yellow_taxi_2025_01.sql`](../sql/analyze_gold_yellow_taxi_2025_01.sql) so the daily totals and weekday comparisons can be rerun and extended.

The weekday-by-borough results show Manhattan has by far the largest pickup volume and largely drives the overall weekday averages: its average ranges from 77,368 trips on Mondays to 110,572 on Thursdays. Queens is the next-largest group (about 8,000–11,000 pickups per average day), while the other boroughs contribute much smaller counts. The lookup value `Unknown` is distinct from `Unknown / unmapped`: the former is a borough label supplied by the zone lookup, while the latter represents a SQL `NULL` borough in the Gold view. These are descriptive results for January only; they do not establish why demand varies.

The ten busiest Manhattan pickup zones account for about 40.5% of Manhattan pickups in this dataset. Midtown Center leads with 169,977 trips (5.50%), followed by Upper East Side South (163,702; 5.30%) and Upper East Side North (155,644; 5.04%). The rest of the top ten each account for about 3.1–4.1%. This measures pickup volume by TLC zone; it does not identify passenger purpose or revenue.

For trips picked up in Midtown Center, the ten most frequent dropoff zones are all in Manhattan and account for about 41.5% of those trips. The leading destination is Upper East Side South (11,463; 6.74%), followed by Upper East Side North (9,845; 5.79%). This top-ten result does not show the full borough distribution; query all dropoff boroughs before concluding that trips mostly stay within Manhattan.

The full dropoff-borough breakdown reconciles to 169,977 Midtown Center pickups. Manhattan receives 160,347 (94.33%); Queens receives 5,527 (3.25%); Brooklyn receives 2,636 (1.55%); EWR receives 535 (0.31%); and the remaining categories are smaller. `Unknown` (432) and `Unknown / unmapped` (210) are separate labels, as with pickup boroughs. Displayed percentages sum to 99.99% because each is rounded to two decimal places. This result shows that nearly all trips from this pickup zone end in Manhattan in this January dataset; it does not establish why.

Breaking the Midtown Center results out by weekday gives Manhattan dropoff shares between 92.07% and 95.28%. Sunday is lowest (11,742 of 12,754 trips; 92.07%); Tuesday is highest (25,914 of 27,199; 95.28%). The weekday counts reconcile to the prior totals: 169,977 pickups and 160,347 Manhattan dropoffs. The query calculates a trip-weighted share for each weekday, and January provides only four or five dates per weekday, so treat the small differences as descriptive rather than a stable behavioral pattern.

### Negative Fare and Total Review (October 18, 2026)

The January table contains 144,118 rows with a negative `fare_amount` and 63,037 with a negative `total_amount`. Negative rows occur across payment types: they are not confined to `payment_type = 3` (no charge) or `payment_type = 4` (dispute). Some inspected examples have fares around -$700 to -$900 alongside very short or zero-distance trips. These are strong review candidates, but the payment code alone does not explain them. The TLC dictionary defines the payment codes and distinguishes meter fare from total charged; it does not establish that every negative amount is a valid refund or correction. Keep these records, flag them, and report negative amounts separately in revenue analysis until their meaning is confirmed. The profile SQL now includes a payment-type breakdown.

Use [`../sql/explore_distribution_yellow_taxi_2025_01.sql`](../sql/explore_distribution_yellow_taxi_2025_01.sql) to compare means with medians and upper percentiles, calculate an IQR review fence, see a coarse distance histogram, and inspect extreme rows. Percentiles and IQR fences help identify candidates for review; they do not establish by themselves that a record is erroneous.

#### Vendor 2 Flex Fare Follow-up

An additional drilldown found 540,031 January rows with `payment_type = 0` (Flex Fare). Their `RatecodeID` is SQL `NULL` for all three vendors in this group, so this null pattern is associated with the Flex Fare cohort and should not automatically be treated as an invalid rate code. The [TLC data dictionary](https://www.nyc.gov/assets/tlc/downloads/pdf/data_dictionary_trip_records_yellow.pdf) defines `payment_type = 0` as Flex Fare; it separately lists rate code `99` as null/unknown, which is not the same database value as SQL `NULL`.

Negative fares in this Flex Fare group are concentrated in `VendorID = 2`: 84,822 of 451,456 Vendor 2 Flex Fare rows (about 18.8%) have a negative fare, compared with zero negative fares among 88,204 Vendor 1 rows and 371 Vendor 6 rows. All 3,421 negative totals in this Flex Fare group also come from Vendor 2. This is a provider-specific review signal, not a basis for excluding all Vendor 2 records.

The negative-fare rate for Vendor 2 Flex Fare rows was 41.25% on January 1 (5,492 of 13,313 trips), compared with 25.33% on January 2 and approximately 15–21% on most later days. Negative totals were especially concentrated on January 1: 3,158 of the month's 3,421 negative totals in this cohort. An hourly check found negative fares in all 24 hours of January 1 (about 27.9–59.7% per hour). January 2 had a wider hourly range (about 12.8–53.5%), with smaller counts in many hours, so the data do not establish a clean reset at midnight.

A component-sum check on the negative-amount Vendor 2 Flex Fare subset found 2,198 rows whose `total_amount` matched the sum of listed fare components and 82,624 with a nonzero difference; differences ranged from -$3.50 to $62.50. Treat this as a comparison, not a definitive reconciliation failure: TLC defines `fare_amount` as a meter-calculated fare, while [Flex Fare is an upfront, non-metered fare](https://www.nyc.gov/assets/tlc/downloads/pdf/rule_book_current_chapter_51.pdf). Keep the raw values and flags, and document this provider-specific behavior as unresolved until the source reporting semantics are confirmed. Do not reject these rows based solely on payment type, provider, null rate code, or component difference.

## Practical Data Quality Procedure

1. **Preserve the inputs.** Keep downloaded files and ingested source tables unchanged. Record source file, load time, and preferably a file checksum so a row can be traced back to its origin.
2. **Set a schema contract.** Define expected column names, types, timestamp conventions, and required fields. Compare each incoming file to the contract before inserting it. The current ingestion code lets Pandas and SQLAlchemy infer table types from the first batch; a more controlled pipeline should define destination types explicitly.
3. **Profile each load.** Check row counts, date coverage, nulls, distinct values, ranges, duplicates, and distribution percentiles. Compare counts to source-file metadata when available.
4. **Apply documented rules.** Separate hard failures (unparseable required values, impossible timestamp order, negative distances) from suspicious values (extreme fare, distance, or duration). Reject hard failures with a reason; flag suspicious values for review instead of silently dropping them.
5. **Reconcile results.** Track accepted and rejected counts and ensure they account for the input rows. Review rejection reasons and changes in distributions between loads.
6. **Make reruns safe.** Use a load identifier or source-file registry to prevent appending the same file twice. Build derived tables from a known complete source and make replacement behavior explicit.

## Next Steps for This Repository

- Inspect the extreme records and decide documented review thresholds; avoid deleting negative fares or missing passenger counts without a business rule.
- Review representative rows from `yellow_taxi_trips_2025_01_flagged`, especially zero-distance trips, missing passenger counts, and negative amounts.
- Add a rejects table with a rejection reason so excluded rows remain explainable.
- Generalize the SQL for other months or a fully ingested year, with explicit source and date boundaries.
- Replace inferred PostgreSQL types with an explicit schema as the ingestion pipeline is hardened.
