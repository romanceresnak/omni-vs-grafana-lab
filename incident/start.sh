#!/usr/bin/env bash
# Starts an incident and writes the start time to incident/timeline.log
#   ./incident/start.sh a        inventory 2.0.0 (price-rule cache bug, tenant-b)
#   ./incident/start.sh b        payments 1.4.0 (synchronous fraud check, tenant-c)
#   ./incident/start.sh blind    random a or b; the answer goes to incident/.answer (don't peek)
set -euo pipefail
cd "$(dirname "$0")"
MODE="${1:-a}"
if [ "$MODE" = "blind" ]; then MODE=$([ $((RANDOM % 2)) -eq 0 ] && echo a || echo b); echo "$MODE" > .answer; SHOWN="blind"; else SHOWN="$MODE"; fi
RA="service.namespace=shop,deployment.environment=lab"
ts(){ date -u +%Y-%m-%dT%H:%M:%SZ; }
echo "$(ts) INCIDENT START ($SHOWN)" | tee -a timeline.log
if [ "$MODE" = "a" ]; then
  kubectl -n shop set env deploy/inventory FEATURE_PRICE_RULES_V2=true OTEL_RESOURCE_ATTRIBUTES="$RA,service.version=2.0.0" >/dev/null
  kubectl -n shop annotate deploy/inventory kubernetes.io/change-cause="release 2.0.0" --overwrite >/dev/null
  kubectl -n shop rollout status deploy/inventory --timeout=420s >/dev/null
else
  kubectl -n shop set env deploy/payments FEATURE_SYNC_FRAUD_CHECK=true OTEL_RESOURCE_ATTRIBUTES="$RA,service.version=1.4.0" >/dev/null
  kubectl -n shop annotate deploy/payments kubernetes.io/change-cause="release 1.4.0" --overwrite >/dev/null
  kubectl -n shop rollout status deploy/payments --timeout=420s >/dev/null
fi
echo "$(ts) new version running ($SHOWN)" | tee -a timeline.log
echo "From now on: ./incident/mark.sh \"<what happened>\" for every milestone."
