"""Steady traffic: RPS requests per second, tenant-a 50%, tenant-b 25%, tenant-c 25%.
Not instrumented on purpose, so it doesn't show up as a service."""
import os
import random
import threading
import time

import requests

URL = os.environ.get("TARGET_URL", "http://storefront:8080/checkout")
RPS = float(os.environ.get("RPS", "5"))
TENANTS = ["tenant-a", "tenant-a", "tenant-b", "tenant-c"]


def one():
    t = random.choice(TENANTS)
    try:
        requests.get(URL, headers={"X-Tenant": t}, timeout=8)
    except requests.RequestException:
        pass


if __name__ == "__main__":
    print(f"loadgen -> {URL} at {RPS} rps", flush=True)
    while True:
        threading.Thread(target=one, daemon=True).start()
        time.sleep(1.0 / RPS)
