"""
NYC TLC Trip Data Downloader
Downloads Yellow, Green, FHV, and FHVHV parquet datasets directly from NYC TLC CloudFront.
"""

import argparse
from concurrent.futures import ThreadPoolExecutor, as_completed
import os
from pathlib import Path
import sys
import time
import urllib.error
import urllib.request


BASE_URL = "https://d37ci6vzurychx.cloudfront.net/trip-data"
ZONES_URL = "https://d37ci6vzurychx.cloudfront.net/misc/taxi_zone_lookup.csv"

# Earliest available year by taxi type
EARLIEST_YEARS = {
    "yellow": 2009,
    "green": 2013,
    "fhv": 2015,
    "fhvhv": 2019,
}


def human_size(bytes_val: int) -> str:
    """Format bytes into human-readable string."""
    for unit in ["B", "KB", "MB", "GB", "TB"]:
        if abs(bytes_val) < 1024.0:
            return f"{bytes_val:3.1f} {unit}"
        bytes_val /= 1024.0
    return f"{bytes_val:.1f} PB"


def download_file(url: str, dest_path: Path, chunk_size: int = 1024 * 512, max_retries: int = 3) -> tuple[bool, str, int]:
    """
    Downloads a single file safely using a temporary file.
    Returns (success: bool, status_message: str, bytes_downloaded: int).
    """
    filename = dest_path.name
    temp_path = dest_path.with_suffix(dest_path.suffix + ".part")

    # If already downloaded and not empty, skip
    if dest_path.exists() and dest_path.stat().st_size > 0:
        size = dest_path.stat().st_size
        return True, f"[SKIP] {filename} already exists ({human_size(size)})", 0

    req = urllib.request.Request(
        url,
        headers={"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"}
    )

    for retry in range(max_retries):
        try:
            with urllib.request.urlopen(req, timeout=45) as response:
                content_length = response.headers.get("Content-Length")

                downloaded = 0
                start_time = time.time()
                with open(temp_path, "wb") as f:
                    while True:
                        chunk = response.read(chunk_size)
                        if not chunk:
                            break
                        f.write(chunk)
                        downloaded += len(chunk)

                # Atomic replace with retry for Windows file locks (antivirus/indexer)
                replaced = False
                for attempt in range(10):
                    try:
                        os.replace(temp_path, dest_path)
                        replaced = True
                        break
                    except (PermissionError, OSError):
                        time.sleep(0.5)

                if not replaced:
                    # Fallback: if replace failed after 10 attempts, try shutil.move
                    import shutil
                    shutil.move(str(temp_path), str(dest_path))

                duration = max(time.time() - start_time, 0.01)
                speed = downloaded / duration

                return (
                    True,
                    f"[DONE] {filename} ({human_size(downloaded)} in {duration:.1f}s, {human_size(speed)}/s)",
                    downloaded,
                )

        except urllib.error.HTTPError as e:
            try:
                if temp_path.exists():
                    temp_path.unlink()
            except Exception:
                pass

            if e.code == 404:
                return False, f"[NOT FOUND] {filename} (HTTP 404)", 0
            elif e.code == 403:
                # 403 can be CloudFront rate limiting; retry with backoff
                if retry < max_retries - 1:
                    time.sleep(2.0 * (retry + 1))
                    continue
                return False, f"[NOT FOUND/FORBIDDEN] {filename} (HTTP 403)", 0
            else:
                if retry < max_retries - 1:
                    time.sleep(1.0 * (retry + 1))
                    continue
                return False, f"[ERROR] {filename} HTTP {e.code}: {e.reason}", 0

        except Exception as e:
            try:
                if temp_path.exists():
                    temp_path.unlink()
            except Exception:
                pass
            if retry < max_retries - 1:
                time.sleep(1.0 * (retry + 1))
                continue
            return False, f"[ERROR] {filename}: {str(e)}", 0

    return False, f"[FAILED] {filename} after {max_retries} retries", 0


def generate_file_list(types: list[str], start_year: int, end_year: int, months: list[int]) -> list[tuple[str, str]]:
    """Generates (url, filename) pairs based on selected criteria."""
    items = []
    for taxi_type in types:
        min_year = EARLIEST_YEARS.get(taxi_type, 2009)
        effective_start = max(start_year, min_year)

        for year in range(effective_start, end_year + 1):
            for month in months:
                # Green taxi began Aug 2013
                if taxi_type == "green" and year == 2013 and month < 8:
                    continue
                # FHVHV began Feb 2019
                if taxi_type == "fhvhv" and year == 2019 and month < 2:
                    continue

                filename = f"{taxi_type}_tripdata_{year}-{month:02d}.parquet"
                url = f"{BASE_URL}/{filename}"
                items.append((url, filename))

    return items


def parse_args():
    parser = argparse.ArgumentParser(description="Download NYC Taxi & Limousine Commission (TLC) Parquet Trip Data")
    parser.add_argument(
        "--types",
        nargs="+",
        default=["yellow"],
        choices=["yellow", "green", "fhv", "fhvhv", "all"],
        help="Taxi data types to download (default: yellow; use 'all' for all 4 types)",
    )
    parser.add_argument(
        "--start-year",
        type=int,
        default=2024,
        help="Start year (e.g. 2009 to 2026, default: 2024)",
    )
    parser.add_argument(
        "--end-year",
        type=int,
        default=2024,
        help="End year (e.g. 2024, default: 2024)",
    )
    parser.add_argument(
        "--months",
        nargs="+",
        type=int,
        default=list(range(1, 13)),
        help="Specific months to download (1-12, default: 1 through 12)",
    )
    parser.add_argument(
        "--dest",
        type=str,
        default="nyc_taxi_data",
        help="Destination directory (default: nyc_taxi_data)",
    )
    parser.add_argument(
        "--workers",
        type=int,
        default=4,
        help="Number of concurrent download threads (default: 4)",
    )
    parser.add_argument(
        "--include-zones",
        action="store_true",
        default=True,
        help="Also download taxi_zone_lookup.csv (default: True)",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Show list of URLs to download without actually downloading",
    )
    return parser.parse_args()


def main():
    args = parse_args()

    types = args.types
    if "all" in types:
        types = ["yellow", "green", "fhv", "fhvhv"]

    dest_dir = Path(args.dest)
    dest_dir.mkdir(parents=True, exist_ok=True)

    items = generate_file_list(types, args.start_year, args.end_year, args.months)

    print("=" * 60)
    print("NYC TLC Taxi Data Downloader")
    print("=" * 60)
    print(f"Dataset Types: {', '.join(types)}")
    print(f"Year Range:    {args.start_year} - {args.end_year}")
    print(f"Months:        {', '.join(str(m) for m in args.months)}")
    print(f"Destination:   {dest_dir.resolve()}")
    print(f"Total Files:   {len(items)}")
    print("=" * 60)

    if args.dry_run:
        print("\nDry-run mode: Planned file downloads:")
        for url, fname in items:
            print(f" - {fname} <- {url}")
        return

    # Optionally download zones CSV
    if args.include_zones:
        zone_file = dest_dir / "taxi_zone_lookup.csv"
        if not zone_file.exists():
            print("\nDownloading Taxi Zone Lookup CSV...")
            ok, msg, _ = download_file(ZONES_URL, zone_file)
            print(msg)

    print(f"\nStarting download with {args.workers} concurrent workers...\n")

    total_downloaded_bytes = 0
    success_count = 0
    not_found_count = 0
    error_count = 0

    t0 = time.time()

    with ThreadPoolExecutor(max_workers=args.workers) as executor:
        future_to_file = {
            executor.submit(download_file, url, dest_dir / fname): fname
            for url, fname in items
        }

        for i, future in enumerate(as_completed(future_to_file), 1):
            fname = future_to_file[future]
            try:
                ok, msg, byte_count = future.result()
                total_downloaded_bytes += byte_count
                if ok:
                    success_count += 1
                elif "NOT FOUND" in msg:
                    not_found_count += 1
                else:
                    error_count += 1

                print(f"[{i}/{len(items)}] {msg}")
            except Exception as exc:
                error_count += 1
                print(f"[{i}/{len(items)}] [CRASH] {fname}: {exc}")

    elapsed = time.time() - t0
    print("\n" + "=" * 60)
    print("Summary:")
    print(f"Total time:       {elapsed:.1f}s")
    print(f"Successful/Skipped: {success_count}")
    print(f"Not Available:    {not_found_count}")
    print(f"Errors:           {error_count}")
    print(f"Total Downloaded: {human_size(total_downloaded_bytes)}")
    print("=" * 60)


if __name__ == "__main__":
    main()
