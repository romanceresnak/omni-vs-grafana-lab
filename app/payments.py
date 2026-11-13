"""payments: always a bit noisy. The 'card network' warning fires before AND
during the incidents. It is the red herring an investigator should not chase.

INCIDENT B lives here. Release 1.4.0 (FEATURE_SYNC_FRAUD_CHECK=true) runs a
synchronous fraud check for tenant-c that takes 0.3-2.6 s. orders gives up
after 2 s, so some tenant-c checkouts fail and the rest are slow."""
import os
import random
import time

from flask import Flask, jsonify

from common import PORT, log, tenant, work

app = Flask(__name__)
SYNC_FRAUD = os.environ.get("FEATURE_SYNC_FRAUD_CHECK", "false").lower() == "true"


def fraud_check(t: str) -> None:
    if SYNC_FRAUD and t == "tenant-c":
        took = random.uniform(0.3, 2.6)
        time.sleep(took)
        if took > 1.5:
            log.info("fraud check slow tenant=%s took_ms=%d", t, int(took * 1000))


@app.get("/health")
def health():
    return "ok"


@app.post("/charge")
def charge():
    t = tenant()
    work(40, 120)
    fraud_check(t)
    if random.random() < 0.04:
        log.warning("card network latency high, retrying tenant=%s", t)
        work(100, 250)
    if random.random() < 0.01:
        log.error("card declined by issuer tenant=%s", t)
        return jsonify(error="declined"), 402
    return jsonify(status="charged"), 200


if __name__ == "__main__":
    log.info("payments starting sync_fraud_check=%s", SYNC_FRAUD)
    app.run(host="0.0.0.0", port=PORT, threaded=True)
