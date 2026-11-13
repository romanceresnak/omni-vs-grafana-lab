#!/usr/bin/env bash
# Deploys the Grafana stack, the collector and the shop. Safe to re-run.
set -euo pipefail
: "${REGION:?run: source env.sh}"
: "${MY_IP:?set your LAPTOP public IP first: echo 1.2.3.4 > ~/.omni-lab-ip && source env.sh}"

# Grafana admin password: created once, kept on re-runs
if ! kubectl -n observability get secret grafana-admin >/dev/null 2>&1; then
  kubectl -n observability create secret generic grafana-admin \
    --from-literal=password="$(openssl rand -base64 18 | tr -d '/+=')"
fi
kubectl -n observability create configmap grafana-dashboards --from-file=grafana/ \
  --dry-run=client -o yaml | kubectl apply -f -
python3 scripts/render.py k8s/20-grafana-stack.yaml | kubectl apply -f -
python3 scripts/render.py k8s/10-collector.yaml   | kubectl apply -f -
kubectl -n observability rollout restart deploy/otel-collector >/dev/null   # pick up config changes

kubectl -n shop create configmap shop-code --from-file=app/ \
  --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -f k8s/30-shop.yaml

echo "Waiting for pods (the shop pods install Python packages on start, ~1-2 min)..."
for d in tempo loki prometheus grafana otel-collector; do kubectl -n observability rollout status deploy/$d --timeout=300s; done
for d in redis payments inventory orders storefront loadgen; do kubectl -n shop rollout status deploy/$d --timeout=420s; done

echo
echo "Grafana:  http://$(kubectl -n observability get svc grafana -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')"
echo "          (the load balancer DNS can take 2-3 minutes to resolve)"
echo "User:     admin"
echo "Password: $(kubectl -n observability get secret grafana-admin -o jsonpath='{.data.password}' | base64 -d)"
