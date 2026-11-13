#!/usr/bin/env bash
# Rolls both services back to the good versions.
set -euo pipefail
cd "$(dirname "$0")"
RA="service.namespace=shop,deployment.environment=lab"
ts(){ date -u +%Y-%m-%dT%H:%M:%SZ; }
echo "$(ts) ROLLBACK started" | tee -a timeline.log
kubectl -n shop set env deploy/inventory FEATURE_PRICE_RULES_V2=false OTEL_RESOURCE_ATTRIBUTES="$RA,service.version=1.0.0" >/dev/null
kubectl -n shop set env deploy/payments  FEATURE_SYNC_FRAUD_CHECK=false OTEL_RESOURCE_ATTRIBUTES="$RA,service.version=1.0.0" >/dev/null
kubectl -n shop rollout status deploy/inventory --timeout=420s
kubectl -n shop rollout status deploy/payments --timeout=420s
echo "$(ts) ROLLBACK done" | tee -a timeline.log
[ -f .answer ] && echo "Blind answer was: incident $(cat .answer)" | tee -a timeline.log && rm .answer || true
