#!/usr/bin/env bash
# Deletes everything this lab created. Omni itself is disabled in the console.
set -euo pipefail
: "${REGION:?run: source env.sh}"
kubectl -n observability delete svc grafana --ignore-not-found --request-timeout=20s 2>/dev/null || true   # remove the load balancer first (ok if kubeconfig is gone)
# CloudShell credentials can expire during a long delete. If eksctl fails with
# "ExpiredToken" or "failed to refresh cached credentials", reload CloudShell and run:
#   unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN
#   eval "$(aws configure export-credentials --format env)"
#   eksctl delete cluster --name "$CLUSTER" --region "$REGION" --wait
# Re-running is safe: eksctl continues where it stopped.
eksctl delete cluster --name "$CLUSTER" --region "$REGION" --wait
aws logs delete-log-group --log-group-name "$LOG_GROUP" --region "$REGION" || true
echo "Done. Left for you: disable CloudWatch Omni / delete the space, and Transaction Search if you don't need it."
