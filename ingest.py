
import argparse
import glob
import os
from time import time
import urllib.request
import pandas as pd
import pyarrow.parquet as pq
from sqlalchemy import create_engine, inspect


def parse_args():
    """Parse command line arguments for the ingestion pipeline."""
    parser = argparse.ArgumentParser(description="Ingest NYC taxi data into PostgreSQL")

    parser.add_argument("--user", required=False, default="root", help="PostgreSQL user")
    parser.add_argument("--password", required=False, default="root", help="PostgreSQL password")
    parser.add_argument("--host", required=False, default="localhost", help="PostgreSQL host")
    parser.add_argument("--port", required=False, default="5432", help="PostgreSQL port")
    parser.add_argument("--db", required=False, default="ny_taxi", help="PostgreSQL database name")
    parser.add_argument("--table_name", required=False, default="yellow_taxi_trips", help="Target table name")
    parser.add_argument("--url", required=False, default=None, help="URL, local file, or glob pattern")
    parser.add_argument("--year", required=False, default=None, help="Year to ingest (e.g. 2025)")
    parser.add_argument(
        "--month",
        type=int,
        choices=range(1, 13),
        required=False,
        help="Optional month to ingest with --year (1-12)",
    )
    parser.add_argument("--taxi_type", required=False, default="yellow", help="Taxi type: yellow, green, fhv")
    parser.add_argument("--chunksize", type=int, default=50_000, help="Number of rows per chunk")
    parser.add_argument(
        "--if_exists",
        choices=["append", "replace"],
        default="append",
        help="Initial table action: 'replace' drops existing table on first file; 'append' keeps existing data",
    )

    return parser.parse_args()


def ingest_parquet(file_path: str, engine, table_name: str, chunksize: int, table_exists: bool, should_replace: bool) -> tuple[int, bool]:
    """Ingest a single Parquet file in memory-safe batches."""
    parquet_file = pq.ParquetFile(file_path)
    total_rows = parquet_file.metadata.num_rows
    print(f"File: {os.path.basename(file_path)} | Total rows: {total_rows:,}")

    batch_iter = parquet_file.iter_batches(batch_size=chunksize)

    # First batch
    first_batch = next(batch_iter)
    df_first = first_batch.to_pandas()

    if not table_exists or should_replace:
        print(f"Creating schema for table '{table_name}' (replace)...")
        df_first.head(0).to_sql(name=table_name, con=engine, if_exists="replace", index=False)
        table_exists = True

    df_first.to_sql(name=table_name, con=engine, if_exists="append", index=False)
    inserted_rows = len(df_first)

    for batch in batch_iter:
        t_start = time()
        df_chunk = batch.to_pandas()
        df_chunk.to_sql(name=table_name, con=engine, if_exists="append", index=False)
        t_end = time()
        inserted_rows += len(df_chunk)
        print(
            f"  -> Inserted {len(df_chunk):,} rows | "
            f"Time: {t_end - t_start:.2f}s | "
            f"Progress: {inserted_rows:,}/{total_rows:,} ({(inserted_rows/total_rows)*100:.1f}%)"
        )

    return inserted_rows, table_exists


def ingest_csv(file_path: str, engine, table_name: str, chunksize: int, table_exists: bool, should_replace: bool) -> tuple[int, bool]:
    """Ingest a CSV file in chunks."""
    print(f"File: {os.path.basename(file_path)} (CSV)")
    df_iter = pd.read_csv(file_path, iterator=True, chunksize=chunksize)

    first_chunk = next(df_iter)
    if not table_exists or should_replace:
        print(f"Creating schema for table '{table_name}' (replace)...")
        first_chunk.head(0).to_sql(name=table_name, con=engine, if_exists="replace", index=False)
        table_exists = True

    first_chunk.to_sql(name=table_name, con=engine, if_exists="append", index=False)
    inserted_rows = len(first_chunk)

    for chunk in df_iter:
        t_start = time()
        chunk.to_sql(name=table_name, con=engine, if_exists="append", index=False)
        t_end = time()
        inserted_rows += len(chunk)
        print(f"  -> Inserted {len(chunk):,} rows | Time: {t_end - t_start:.2f}s")

    return inserted_rows, table_exists


def main():
    args = parse_args()

    if args.month is not None and args.year is None:
        raise SystemExit("[ERROR] --month requires --year")

    user = args.user
    password = args.password
    host = args.host
    port = args.port
    db = args.db
    table_name = args.table_name
    chunksize = args.chunksize
    if_exists = args.if_exists

    # Resolve input files
    files = []
    if args.year:
        month_pattern = f"{args.month:02d}" if args.month is not None else "*"
        pattern = f"nyc_taxi_data/{args.taxi_type}_tripdata_{args.year}-{month_pattern}.parquet"
        files = sorted(glob.glob(pattern))
        date_label = f"{args.year}-{args.month:02d}" if args.month is not None else str(args.year)
        print(f"Resolved {len(files)} files for {date_label} ({args.taxi_type} taxi) matching '{pattern}'")
    elif args.url and (args.url.startswith("http://") or args.url.startswith("https://")):
        file_name = args.url.split("/")[-1]
        print(f"Downloading dataset from {args.url} to {file_name}...")
        urllib.request.urlretrieve(args.url, file_name)
        files = [file_name]
    elif args.url and ("*" in args.url or "?" in args.url):
        files = sorted(glob.glob(args.url))
    elif args.url:
        files = [args.url]
    else:
        # Default fallback
        files = ["yellow_tripdata_2026-01.parquet"]

    if not files:
        print(f"[ERROR] No matching files found to ingest!")
        return

    print(f"Connecting to PostgreSQL at {host}:{port}/{db}...")
    engine = create_engine(f"postgresql://{user}:{password}@{host}:{port}/{db}")

    # Check if table already exists in PostgreSQL
    table_exists = inspect(engine).has_table(table_name)
    total_files = len(files)
    grand_total_rows = 0
    t_global_start = time()

    print(f"Starting ingestion of {total_files} file(s) into table '{table_name}' (Initial action: {if_exists})...")

    for idx, file_path in enumerate(files, start=1):
        print(f"\n==================================================")
        print(f"[{idx}/{total_files}] Processing {file_path}")
        print(f"==================================================")

        # Only replace on the first file if requested; subsequent files must ALWAYS append
        should_replace = (if_exists == "replace" and idx == 1)

        if file_path.endswith(".parquet"):
            rows, table_exists = ingest_parquet(file_path, engine, table_name, chunksize, table_exists, should_replace)
        else:
            rows, table_exists = ingest_csv(file_path, engine, table_name, chunksize, table_exists, should_replace)

        grand_total_rows += rows

    t_global_end = time()
    elapsed = t_global_end - t_global_start

    print(f"\n" + "=" * 60)
    print(f"[SUCCESS] Ingested {total_files} file(s) into '{table_name}'.")
    print(f"Total rows inserted: {grand_total_rows:,}")
    print(f"Total time elapsed : {elapsed / 60:.2f} minutes ({elapsed:.1f} seconds)")
    print(f"Average throughput  : {grand_total_rows / max(elapsed, 1):,.0f} rows/sec")
    print("=" * 60)


if __name__ == "__main__":
    main()

