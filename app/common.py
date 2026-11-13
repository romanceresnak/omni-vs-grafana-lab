"""Shared helpers for the lab services. Instrumentation comes from
`opentelemetry-instrument` (auto-instrumentation), so the code stays plain Flask."""
import logging
import os
import random
import time

from flask import request
from opentelemetry import trace

SERVICE = os.environ.get("OTEL_SERVICE_NAME", "unknown")
PORT = int(os.environ.get("PORT", "8080"))

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s %(message)s")
log = logging.getLogger(SERVICE)
logging.getLogger("werkzeug").setLevel(logging.WARNING)  # no access-log noise


def tenant() -> str:
    """Tenant comes from the X-Tenant header and is put on the current span."""
    t = request.headers.get("X-Tenant", "unknown")
    span = trace.get_current_span()
    span.set_attribute("tenant.id", t)
    return t


def fwd_headers(t: str) -> dict:
    return {"X-Tenant": t}


def work(min_ms: int, max_ms: int) -> None:
    time.sleep(random.uniform(min_ms, max_ms) / 1000.0)
