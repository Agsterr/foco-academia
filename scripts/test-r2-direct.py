#!/usr/bin/env python3
import os
import subprocess
import sys
import uuid

env = {}
for line in subprocess.check_output(
    ["docker", "exec", "foco-academia-api", "printenv"], text=True
).splitlines():
    if "=" in line:
        k, v = line.split("=", 1)
        env[k] = v

bucket = env.get("R2_BUCKET", "")
endpoint = env.get("R2_ENDPOINT", "")
access = env.get("R2_ACCESS_KEY_ID", "")
secret = env.get("R2_SECRET_ACCESS_KEY", "")
public = env.get("R2_PUBLIC_BASE_URL", "").rstrip("/")

print(f"bucket={'OK' if bucket else 'VAZIO'}")
print(f"endpoint={'OK' if endpoint else 'VAZIO'}")
print(f"access={'OK' if access else 'VAZIO'}")
print(f"secret={'OK' if secret else 'VAZIO'}")
print(f"public={'OK' if public else 'VAZIO'}")

try:
    import boto3
    from botocore.config import Config
except ImportError:
    subprocess.check_call([sys.executable, "-m", "pip", "install", "-q", "boto3"])
    import boto3
    from botocore.config import Config

key = f"test-{uuid.uuid4()}.png"
data = (
    b"\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01"
    b"\x08\x06\x00\x00\x00\x1f\x15\xc4\x89\x00\x00\x00\nIDATx\x9cc\x00\x01"
    b"\x00\x00\x05\x00\x01\r\n-\xdb\x00\x00\x00\x00IEND\xaeB`\x82"
)

client = boto3.client(
    "s3",
    endpoint_url=endpoint,
    aws_access_key_id=access,
    aws_secret_access_key=secret,
    region_name="auto",
    config=Config(signature_version="s3v4", s3={"addressing_style": "path"}),
)

client.put_object(Bucket=bucket, Key=key, Body=data, ContentType="image/png")
url = f"{public}/{key}"
print(f"PUT_OBJECT=OK")
print(f"URL={url}")

import urllib.request

with urllib.request.urlopen(url) as resp:
    print(f"PUBLIC_HTTP={resp.status}")
