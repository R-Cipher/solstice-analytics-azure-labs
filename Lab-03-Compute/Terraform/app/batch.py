"""Solstice nightly manifest processor.

Reads every CSV in the raw-manifests container, counts the rows, and writes a
summary file to the processed container. Authenticates with the user-assigned
managed identity, so there are no keys or SAS tokens in the image.
"""
import csv
import io
import os
from datetime import datetime, timezone

from azure.identity import ManagedIdentityCredential
from azure.storage.blob import BlobServiceClient

account_url = os.environ["STORAGE_ACCOUNT_URL"]
credential = ManagedIdentityCredential(client_id=os.environ["AZURE_CLIENT_ID"])
service = BlobServiceClient(account_url, credential=credential)

raw = service.get_container_client("raw-manifests")
processed = service.get_container_client("processed")

print(f"Processing manifests from {account_url} ...", flush=True)

rows = [("manifest", "data_rows")]
for blob in raw.list_blobs():
    if not blob.name.lower().endswith(".csv"):
        continue
    data = raw.download_blob(blob.name).readall().decode("utf-8")
    count = max(sum(1 for _ in csv.reader(io.StringIO(data))) - 1, 0)  # minus header
    rows.append((blob.name, count))
    print(f"  {blob.name}: {count} rows", flush=True)

out = io.StringIO()
csv.writer(out).writerows(rows)
name = f"summary-{datetime.now(timezone.utc):%Y%m%dT%H%M%SZ}.csv"
processed.upload_blob(name, out.getvalue(), overwrite=True)

print(f"Wrote {name} ({len(rows) - 1} manifests). Done.", flush=True)
