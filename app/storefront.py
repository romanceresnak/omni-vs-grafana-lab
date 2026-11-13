"""storefront: the public entry point. GET /checkout -> orders."""
import os
import random

import requests
from flask import Flask, jsonify

from common import PORT, fwd_headers, log, tenant, work

app = Flask(__name__)
ORDERS = os.environ.get("ORDERS_URL", "http://orders:8080")
SKUS = ["sku-100", "sku-200", "sku-300", "sku-400"]


@app.get("/health")
def health():
    return "ok"


@app.get("/checkout")
def checkout():
    t = tenant()
    work(5, 15)
    sku = random.choice(SKUS)
    try:
        r = requests.post(f"{ORDERS}/orders", json={"sku": sku, "qty": 1},
                          headers=fwd_headers(t), timeout=5)
    except requests.RequestException as e:
        log.error("orders unreachable tenant=%s error=%s", t, e)
        return jsonify(error="orders unreachable"), 502
    if r.status_code >= 500:
        log.error("checkout failed tenant=%s sku=%s orders_status=%s", t, sku, r.status_code)
        return jsonify(error="checkout failed"), 502
    return jsonify(order=r.json()), 200


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=PORT, threaded=True)
