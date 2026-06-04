#!/usr/bin/env python3
"""
DQ Agent — Dataset Ingest Script
Downloads NYC Taxi + OpenAQ datasets locally, then uploads to S3 landing layer.

Usage:
    python scripts/ingest_datasets.py

Requirements:
    pip install boto3 requests --break-system-packages
"""

import os
import json
import boto3
import requests
from datetime import datetime, timezone
from pathlib import Path

# ─────────────────────────────────────────────
# CONFIG
# ─────────────────────────────────────────────
S3_BUCKET       = "dq-agent-datalake-production"
S3_REGION       = "ap-south-1"
AWS_PROFILE     = "default"

LOCAL_DATA_DIR  = Path(__file__).parent.parent / "data" / "raw"

TIMESTAMP       = datetime.now(timezone.utc).strftime("%Y%m%d_%H%M%S")

# ─────────────────────────────────────────────
# NYC TAXI CONFIG
# ─────────────────────────────────────────────
NYC_TAXI_URL    = (
    "https://data.cityofnewyork.us/api/views/biws-g3hs/rows.csv"
    "?accessType=DOWNLOAD"
)
NYC_LOCAL_FILE  = LOCAL_DATA_DIR / "nyc_taxi" / f"nyc_taxi_{TIMESTAMP}.csv"
NYC_S3_KEY      = f"landing/nyc_taxi/nyc_taxi_{TIMESTAMP}.csv"

# ─────────────────────────────────────────────
# OPENAQ CONFIG
# ─────────────────────────────────────────────
OPENAQ_URL      = "https://api.openaq.org/v2/measurements"
OPENAQ_PARAMS   = {
    "country":      "IN",           # India — close to your region
    "parameter":    "pm25",         # PM2.5 particulate matter
    "limit":        1000,
    "date_from":    "2024-01-01",
}
OPENAQ_HEADERS  = {"Accept": "application/json"}
OPENAQ_LOCAL_FILE = LOCAL_DATA_DIR / "openaq" / f"openaq_{TIMESTAMP}.json"
OPENAQ_S3_KEY   = f"landing/openaq/openaq_{TIMESTAMP}.json"


# ─────────────────────────────────────────────
# HELPERS
# ─────────────────────────────────────────────
def log(msg: str):
    print(f"[{datetime.now().strftime('%H:%M:%S')}] {msg}")


def ensure_dirs():
    (LOCAL_DATA_DIR / "nyc_taxi").mkdir(parents=True, exist_ok=True)
    (LOCAL_DATA_DIR / "openaq").mkdir(parents=True, exist_ok=True)
    log("✅ Local directories ready")


def get_s3_client():
    session = boto3.Session(profile_name=AWS_PROFILE, region_name=S3_REGION)
    return session.client("s3")


# ─────────────────────────────────────────────
# NYC TAXI — DOWNLOAD + UPLOAD
# ─────────────────────────────────────────────
def download_nyc_taxi():
    log("🚕 Downloading NYC Taxi dataset...")
    log(f"   Source: {NYC_TAXI_URL}")

    # Stream download to handle large file
    with requests.get(NYC_TAXI_URL, stream=True, timeout=120) as r:
        r.raise_for_status()
        total = 0
        with open(NYC_LOCAL_FILE, "wb") as f:
            for chunk in r.iter_content(chunk_size=1024 * 1024):  # 1MB chunks
                f.write(chunk)
                total += len(chunk)
                if total % (10 * 1024 * 1024) == 0:
                    log(f"   Downloaded {total // (1024*1024)} MB...")

    size_mb = NYC_LOCAL_FILE.stat().st_size / (1024 * 1024)
    log(f"✅ NYC Taxi saved locally: {NYC_LOCAL_FILE} ({size_mb:.1f} MB)")
    return NYC_LOCAL_FILE


def upload_nyc_taxi(s3):
    log(f"📤 Uploading NYC Taxi to s3://{S3_BUCKET}/{NYC_S3_KEY}")
    s3.upload_file(
        str(NYC_LOCAL_FILE),
        S3_BUCKET,
        NYC_S3_KEY,
        ExtraArgs={
            "ContentType": "text/csv",
            "Metadata": {
                "source":    "NYC Open Data",
                "dataset":   "nyc_taxi",
                "ingested":  TIMESTAMP,
            }
        }
    )
    log(f"✅ NYC Taxi uploaded to S3")


# ─────────────────────────────────────────────
# OPENAQ — DOWNLOAD + UPLOAD
# ─────────────────────────────────────────────
def download_openaq():
    log("🌫️  Downloading OpenAQ Air Quality data...")
    log(f"   Source: {OPENAQ_URL}")

    response = requests.get(
        OPENAQ_URL,
        params=OPENAQ_PARAMS,
        headers=OPENAQ_HEADERS,
        timeout=60
    )
    response.raise_for_status()

    data = response.json()
    record_count = len(data.get("results", []))

    with open(OPENAQ_LOCAL_FILE, "w") as f:
        json.dump(data, f, indent=2)

    size_kb = OPENAQ_LOCAL_FILE.stat().st_size / 1024
    log(f"✅ OpenAQ saved locally: {OPENAQ_LOCAL_FILE} ({record_count} records, {size_kb:.1f} KB)")
    return OPENAQ_LOCAL_FILE


def upload_openaq(s3):
    log(f"📤 Uploading OpenAQ to s3://{S3_BUCKET}/{OPENAQ_S3_KEY}")
    s3.upload_file(
        str(OPENAQ_LOCAL_FILE),
        S3_BUCKET,
        OPENAQ_S3_KEY,
        ExtraArgs={
            "ContentType": "application/json",
            "Metadata": {
                "source":    "OpenAQ API v2",
                "dataset":   "openaq",
                "parameter": "pm25",
                "country":   "IN",
                "ingested":  TIMESTAMP,
            }
        }
    )
    log(f"✅ OpenAQ uploaded to S3")


# ─────────────────────────────────────────────
# VERIFY — LIST S3 LANDING FILES
# ─────────────────────────────────────────────
def verify_s3(s3):
    log("\n📋 Verifying S3 landing layer contents...")
    for prefix in ["landing/nyc_taxi/", "landing/openaq/"]:
        response = s3.list_objects_v2(Bucket=S3_BUCKET, Prefix=prefix)
        files = response.get("Contents", [])
        if files:
            for f in files[-3:]:  # Show last 3 files
                size_kb = f["Size"] / 1024
                log(f"   s3://{S3_BUCKET}/{f['Key']} ({size_kb:.1f} KB)")
        else:
            log(f"   ⚠️  No files found under {prefix}")


# ─────────────────────────────────────────────
# MAIN
# ─────────────────────────────────────────────
def main():
    log("=" * 55)
    log("DQ Agent — Dataset Ingest")
    log(f"Bucket : {S3_BUCKET}")
    log(f"Region : {S3_REGION}")
    log(f"Profile: {AWS_PROFILE}")
    log("=" * 55)

    ensure_dirs()
    s3 = get_s3_client()

    # NYC Taxi
    try:
        download_nyc_taxi()
        upload_nyc_taxi(s3)
    except Exception as e:
        log(f"❌ NYC Taxi failed: {e}")

    # OpenAQ
    try:
        download_openaq()
        upload_openaq(s3)
    except Exception as e:
        log(f"❌ OpenAQ failed: {e}")

    # Verify
    verify_s3(s3)

    log("\n✅ Ingest complete.")


if __name__ == "__main__":
    main()
