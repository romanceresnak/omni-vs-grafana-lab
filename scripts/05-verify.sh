#!/usr/bin/env bash
# Checks that the SAME telemetry reaches both worlds. Run 3-5 minutes after deploy.
set -uo pipefail
: "${REGION:?run: source env.sh}"
ok(){ echo "  [OK]   $*"; }; bad(){ echo "  [FAIL] $*"; }
pf(){ kubectl -n observability port-forward "svc/$1" "$2:$2" >/dev/null 2>&1 & echo $!; }

echo "1. Pods"
kubectl get pods -n observability --no-headers | awk '{print "  " $1, $3}'
kubectl get pods -n shop --no-headers | awk '{print "  " $1, $3}'

echo "2. Collector exporters (errors in the last 5 minutes)"
LOGS=$(kubectl -n observability logs deploy/otel-collector --since=5m)
ERR=$(printf '%s\n' "$LOGS" | grep -cP '\t(error|warn)\t.*(Exporting failed|Dropping|denied|status code)' || true)
if [ "$ERR" = "0" ]; then ok "no export errors"; else
  bad "$ERR export error lines, last ones:"
  printf '%s\n' "$LOGS" | grep -P '\t(error|warn)\t' | grep -oE '"otelcol.component.id": "[^"]*"|"error": "[^"]{0,160}' | tail -6 | sed 's/^/         /'
fi

P1=$(pf prometheus 9090); P2=$(pf tempo 3200); P3=$(pf loki 3100); sleep 4
echo "3. Grafana world"
N=$(curl -s 'localhost:9090/api/v1/query' --data-urlencode 'query=count(lab_spanmetrics_calls_total)' | python3 -c 'import json,sys; r=json.load(sys.stdin)["data"]["result"]; print(r[0]["value"][1] if r else 0)')
[ "$N" != "0" ] && ok "Prometheus: $N spanmetrics series" || bad "Prometheus: no lab_spanmetrics_calls_total"
T=$(curl -s 'localhost:3200/api/search?tags=service.name%3Dstorefront&limit=5' | python3 -c 'import json,sys; print(len(json.load(sys.stdin).get("traces",[])))')
[ "$T" != "0" ] && ok "Tempo: storefront traces found" || bad "Tempo: no storefront traces"
L=$(curl -s 'localhost:3100/loki/api/v1/label/service_name/values' | python3 -c 'import json,sys; print(",".join(json.load(sys.stdin).get("data",[])))')
[ -n "$L" ] && ok "Loki: service_name = $L" || bad "Loki: no service_name label"
kill $P1 $P2 $P3 2>/dev/null

echo "4. CloudWatch world"
S=$(aws logs describe-log-streams --log-group-name "$LOG_GROUP" --region "$REGION" --query 'length(logStreams)' --output text 2>/dev/null)
[ "${S:-0}" != "0" ] && ok "Logs: $LOG_GROUP has $S stream(s)" || bad "Logs: nothing in $LOG_GROUP yet"
SP=$(aws logs describe-log-groups --log-group-name-prefix aws/spans --region "$REGION" --query 'length(logGroups)' --output text 2>/dev/null)
[ "${SP:-0}" != "0" ] && ok "Spans: aws/spans log group exists (Transaction Search)" || bad "Spans: no aws/spans log group - is Transaction Search on?"
echo "  Metrics and the application map: check in Omni (Application map -> application 'shop')."
