"""Waits for Windows file locks to clear, then renames .part -> .parquet"""
import os, time, pathlib

parts = [
    ("nyc_taxi_data/fhvhv_tripdata_2022-04.parquet.part", "nyc_taxi_data/fhvhv_tripdata_2022-04.parquet"),
    ("nyc_taxi_data/fhvhv_tripdata_2022-05.parquet.part", "nyc_taxi_data/fhvhv_tripdata_2022-05.parquet"),
]

for src, dst in parts:
    src_path = pathlib.Path(src)
    dst_path = pathlib.Path(dst)
    if dst_path.exists():
        print(f"Already complete: {dst}")
        continue
    if not src_path.exists():
        print(f"Part file missing (already renamed?): {src}")
        continue
    print(f"Waiting for lock to clear on {src} ...")
    for attempt in range(60):
        try:
            os.replace(src, dst)
            print(f"[OK] Renamed -> {dst}")
            break
        except PermissionError:
            print(f"  Attempt {attempt+1}/60: still locked, waiting 5s...")
            time.sleep(5)
    else:
        print(f"[FAIL] Could not rename {src} after 5 minutes.")
