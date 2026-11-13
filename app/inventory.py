"""inventory: stock + per-tenant price rules, cached in Redis.

THE INCIDENT lives here. Release 2.0.0 (FEATURE_PRICE_RULES_V2=true) moves the
price-rule cache to a new key layout, but reads `pr2:rule:` and writes
`pr2:rules:`.
Every read is a miss, every miss costs a slow "database" lookup.
tenant-b has 40 price rules, the others have 2, so only tenant-b really hurts.
"""
import os
import time

import redis
from flask import Flask, jsonify, request

from common import PORT, log, tenant, work

app = Flask(__name__)
r = redis.Redis(host=os.environ.get("REDIS_HOST", "redis"), port=6379, socket_timeout=1)

V2 = os.environ.get("FEATURE_PRICE_RULES_V2", "false").lower() == "true"
RULES_PER_TENANT = {"tenant-a": 2, "tenant-b": 40, "tenant-c": 2}
DB_LOOKUP_MS = 18


def db_lookup() -> str:
    time.sleep(DB_LOOKUP_MS / 1000.0)  # stands in for a slow database query
    return "1.00"


def price_rules(t: str) -> int:
    n = RULES_PER_TENANT.get(t, 2)
    misses = 0
    for i in range(n):
        if V2:
            read_key, write_key = f"pr2:rule:{t}:{i}", f"pr2:rules:{t}:{i}"   # the bug
        else:
            read_key = write_key = f"rule:{t}:{i}"
        if r.get(read_key) is None:
            misses += 1
            r.set(write_key, db_lookup(), ex=3600)
    if misses > 5:
        log.warning("price rule cache miss tenant=%s misses=%d of %d", t, misses, n)
    return misses


@app.get("/health")
def health():
    return "ok"


@app.get("/reserve")
def reserve():
    t = tenant()
    sku = request.args.get("sku", "sku-100")
    work(3, 10)
    stock = r.get(f"stock:{sku}")
    if stock is None:
        r.set(f"stock:{sku}", 1000, ex=3600)
    misses = price_rules(t)
    return jsonify(sku=sku, price=19.99, rule_cache_misses=misses), 200


if __name__ == "__main__":
    log.info("inventory starting price_rules_v2=%s", V2)
    app.run(host="0.0.0.0", port=PORT, threaded=True)
