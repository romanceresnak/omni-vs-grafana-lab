#!/usr/bin/env bash
# AWS side: log group for OTLP logs + check that Transaction Search is on.
set -euo pipefail
: "${REGION:?run: source env.sh}"
aws logs create-log-group --log-group-name "$LOG_GROUP" --region "$REGION" 2>/dev/null || true
aws logs put-retention-policy --log-group-name "$LOG_GROUP" --retention-in-days 7 --region "$REGION"
# The OTLP logs endpoint does NOT create the stream named in x-aws-log-stream (HTTP 400 otherwise)
aws logs create-log-stream --log-group-name "$LOG_GROUP" --log-stream-name otel-collector --region "$REGION" 2>/dev/null || true
echo "Log group $LOG_GROUP ready (7 days retention)."
echo
echo "Transaction Search (needed for spans in CloudWatch/Omni):"
aws xray get-trace-segment-destination --region "$REGION" || true
echo "Expected: Destination = CloudWatchLogs, Status = ACTIVE."
echo "If not: enable it in the Omni setup (OTel span ingestion) or in CloudWatch > Settings > Transaction Search."
