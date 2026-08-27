"""
One-off diagnostic: ask Google directly which Firestore database(s) exist
for this project, and what their real IDs are. Run this locally:

    python check_databases.py

Needs: google-auth, requests (both are already installed as dependencies
of firebase-admin, which you already used for seed.py).
"""
import json

import requests
from google.oauth2 import service_account
import google.auth.transport.requests

with open("serviceAccountKey.json") as f:
    key = json.load(f)
project_id = key["project_id"]

creds = service_account.Credentials.from_service_account_file(
    "serviceAccountKey.json",
    scopes=["https://www.googleapis.com/auth/cloud-platform"],
)
creds.refresh(google.auth.transport.requests.Request())

resp = requests.get(
    f"https://firestore.googleapis.com/v1/projects/{project_id}/databases",
    headers={"Authorization": f"Bearer {creds.token}"},
)
print("project:", project_id)
print("status:", resp.status_code)
print(json.dumps(resp.json(), indent=2))
