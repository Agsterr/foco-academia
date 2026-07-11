#!/usr/bin/env python3
import subprocess
import uuid

env = {}
for line in subprocess.check_output(["docker", "exec", "foco-academia-api", "printenv"], text=True).splitlines():
    if "=" in line:
        k, v = line.split("=", 1)
        env[k] = v

import boto3
from botocore.config import Config

key = f"java-like-{uuid.uuid4()}.png"
data = b"\x89PNG\r\n\x1a\n"

client = boto3.client(
    "s3",
    endpoint_url=env["R2_ENDPOINT"],
    aws_access_key_id=env["R2_ACCESS_KEY_ID"],
    aws_secret_access_key=env["R2_SECRET_ACCESS_KEY"],
    region_name="us-east-1",
    config=Config(signature_version="s3v4", s3={"addressing_style": "path"}),
)
client.put_object(Bucket=env["R2_BUCKET"], Key=key, Body=data, ContentType="image/png")
print("JAVA_LIKE_PUT=OK")
