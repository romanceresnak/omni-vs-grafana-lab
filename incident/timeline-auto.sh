#!/usr/bin/env bash
# Pulls alert state changes after an incident, from both worlds, relative to the last INCIDENT START.
#   ./incident/timeline-auto.sh
set -uo pipefail
cd "$(dirname "$0")/.."
: "${REGION:?run: source env.sh}"

START=$(grep "INCIDENT START" incident/timeline.log | tail -1 | cut -d' ' -f1)
[ -z "$START" ] && { echo "No INCIDENT START in incident/timeline.log"; exit 1; }
echo "Incident start: $START"
echo

kubectl -n observability port-forward svc/prometheus 9090:9090 >/dev/null 2>&1 & PF=$!; sleep 3
python3 - "$START" <<'EOF'
import json, sys, urllib.parse, urllib.request, datetime as dt
start = dt.datetime.fromisoformat(sys.argv[1].replace("Z", "+00:00"))
now = dt.datetime.now(dt.timezone.utc)
q = urllib.parse.urlencode({"query": "ALERTS", "start": (start - dt.timedelta(minutes=5)).timestamp(),
                            "end": now.timestamp(), "step": "15"})
data = json.load(urllib.request.urlopen("http://localhost:9090/api/v1/query_range?" + q))["data"]["result"]
rows = []
for s in data:
    m = s["metric"]
    first = dt.datetime.fromtimestamp(float(s["values"][0][0]), dt.timezone.utc)
    if first < start:  # was already active before the incident
        continue
    who = m.get("tenant_id", "")
    rows.append((first, f'grafana: {m["alertname"]}{" ("+who+")" if who else ""} {m["alertstate"]}'))
print("GRAFANA (Prometheus ALERTS, 15 s resolution)")
for t, txt in sorted(rows):
    print(f"  {t:%H:%M:%S}  +{int((t-start).total_seconds()):>4}s  {txt}")
if not rows:
    print("  no alert became pending/firing after the start")
EOF
kill $PF 2>/dev/null
echo

echo "OMNI (CloudWatch alarm history, if Omni alerts are CloudWatch alarms)"
ALARMS=$(aws cloudwatch describe-alarms --region "$REGION" --query "MetricAlarms[?contains(AlarmName,'storefront')].AlarmName" --output text)
if [ -z "$ALARMS" ]; then
  echo "  no CloudWatch alarms named *storefront* found -> read the times in Omni > Alerts and mark them by hand"
else
  for A in $ALARMS; do
    aws cloudwatch describe-alarm-history --region "$REGION" --alarm-name "$A" \
      --history-item-type StateUpdate --start-date "$START" \
      --query 'AlarmHistoryItems[].[Timestamp,HistorySummary]' --output text | sort | sed "s/^/  $A  /"
  done
fi
echo
echo "Manual marks (incident/timeline.log):"
sed "s/^/  /" incident/timeline.log | tail -20
