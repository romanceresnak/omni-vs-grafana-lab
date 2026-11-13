"""orders: reserves stock in inventory, then charges in payments.
Inventory calls time out after 800 ms -> 504. That is where the incident becomes visible."""
import os
import uuid

import requests
from flask import Flask, jsonify, request

from common import PORT, fwd_headers, log, tenant, work

app = Flask(__name__)
INVENTORY = os.environ.get("INVENTORY_URL", "http://inventory:8080")
PAYMENTS = os.environ.get("PAYMENTS_URL", "http://payments:8080")
INVENTORY_TIMEOUT_S = float(os.environ.get("INVENTORY_TIMEOUT_S", "0.8"))


@app.get("/health")
def health():
    return "ok"


@app.post("/orders")
def create_order():
    t = tenant()
    body = request.get_json(silent=True) or {}
    sku = body.get("sku", "sku-100")
    work(5, 20)

    try:
        inv = requests.get(f"{INVENTORY}/reserve", params={"sku": sku},
                           headers=fwd_headers(t), timeout=INVENTORY_TIMEOUT_S)
    except requests.Timeout:
        log.error("inventory timeout after %d ms tenant=%s sku=%s",
                  int(INVENTORY_TIMEOUT_S * 1000), t, sku)
        return jsonify(error="inventory timeout"), 504
    if inv.status_code != 200:
        log.error("inventory error tenant=%s status=%s", t, inv.status_code)
        return jsonify(error="inventory error"), 502

    try:
        pay = requests.post(f"{PAYMENTS}/charge", json={"amount": inv.json()["price"]},
                            headers=fwd_headers(t), timeout=2)
    except requests.Timeout:
        log.error("payment timeout after 2000 ms tenant=%s", t)
        return jsonify(error="payment timeout"), 504
    if pay.status_code != 200:
        log.error("payment failed tenant=%s status=%s", t, pay.status_code)
        return jsonify(error="payment failed"), 502

    order_id = str(uuid.uuid4())[:8]
    log.info("order created id=%s tenant=%s sku=%s", order_id, t, sku)
    return jsonify(id=order_id, sku=sku, price=inv.json()["price"]), 201


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=PORT, threaded=True)
