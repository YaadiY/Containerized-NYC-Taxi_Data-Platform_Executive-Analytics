
import argparse
import os
from time import time
import urllib.request
import pandas as pd
import pyarrow.parquet as pq
from sqlalchemy import create_engine


def parse_args():
    """Parse command line arguments for the ingestion pipeline."""
    parser = argparse.ArgumentParser(description="Ingest NYC taxi data into PostgreSQL")

    parser.add_argument("--user", required=False, default="root", help="PostgreSQL user")
    parser.add_argument("--password", required=False, default="root", help="PostgreSQL password")
    parser.add_argument("--host", required=False, default="localhost", help="PostgreSQL host")
    parser.add_argument("--port", required=False, default="5432", help="PostgreSQL port")
    parser.add_argument("--db", required=False, default="ny_taxi", help="PostgreSQL database name")
    parser.add_argument("--table_name", required=False, default="yellow_taxi_trips", help="Target table name")
    parser.add_argument("--url", required=False, default=None, help="URL or local path of the data file")
    parser.add_argument("--chunksize", type=int, default=100_000, help="Number of rows per chunk")

    return parser.parse_args()


def main():
    args = parse_args()

    user = args.user
    password = args.password
    host = args.host
    port = args.port
    db = args.db
    table_name = args.table_name
    url = args.url
    chunksize = args.chunksize

    # 1. Determine input file path (download if URL is provided, or use local file)
    if url and (url.startswith("http://") or url.startswith("https://")):
        file_name = url.split("/")[-1]
        print(f"Downloading dataset from {url} to {file_name}...")
        urllib.request.urlretrieve(url, file_name)
    elif url:
        file_name = url
    else:
        # Default fallback to existing local parquet file
        file_name = "yellow_tripdata_2026-01.parquet"

    print(f"Connecting to PostgreSQL at {host}:{port}/{db}...")
    engine = create_engine(f"postgresql://{user}:{password}@{host}:{port}/{db}")

    # 2. Ingest based on file format
    if file_name.endswith(".parquet"):
        print(f"Processing Parquet file: {file_name} in chunks of {chunksize:,} rows...")
        parquet_file = pq.ParquetFile(file_name)
        total_rows = parquet_file.metadata.num_rows
        print(f"Total rows detected: {total_rows:,}")

        batch_iter = parquet_file.iter_batches(batch_size=chunksize)

        # Ingest first batch and create table schema
        first_batch = next(batch_iter)
        df_first = first_batch.to_pandas()
        df_first.head(0).to_sql(name=table_name, con=engine, if_exists="replace", index=False)
        df_first.to_sql(name=table_name, con=engine, if_exists="append", index=False)
        
        inserted_rows = len(df_first)
        print(f"Created table '{table_name}' and inserted initial {inserted_rows:,} rows.")

        # Ingest remaining batches
        for batch in batch_iter:
            t_start = time()
            df_chunk = batch.to_pandas()
            df_chunk.to_sql(name=table_name, con=engine, if_exists="append", index=False)
            t_end = time()
            inserted_rows += len(df_chunk)
            print(
                f"Inserted {len(df_chunk):,} rows | "
                f"Time: {t_end - t_start:.2f}s | "
                f"Progress: {inserted_rows:,}/{total_rows:,} ({(inserted_rows/total_rows)*100:.1f}%)"
            )

    else:
        # CSV handling (e.g. taxi_zone_lookup.csv)
        print(f"Processing CSV file: {file_name}...")
        df_iter = pd.read_csv(file_name, iterator=True, chunksize=chunksize)

        first_chunk = next(df_iter)
        first_chunk.head(0).to_sql(name=table_name, con=engine, if_exists="replace", index=False)
        first_chunk.to_sql(name=table_name, con=engine, if_exists="append", index=False)
        print(f"Created table '{table_name}' and inserted first chunk.")

        for chunk in df_iter:
            t_start = time()
            chunk.to_sql(name=table_name, con=engine, if_exists="append", index=False)
            t_end = time()
            print(f"Inserted chunk of {len(chunk):,} rows | Time: {t_end - t_start:.2f}s")

    print(f"\n[SUCCESS] Ingestion completed into table '{table_name}' successfully!")


if __name__ == "__main__":
    main()
