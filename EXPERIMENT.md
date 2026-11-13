# Experiment protocol – "I Gave the Same Incident to CloudWatch Omni and to My Grafana Stack"

Rule number one: **every number in the article comes from `incident/timeline.log`, a screenshot, or a query below.** Nothing from memory.

---

## Step 0 – Set up CloudWatch Omni (console, eu-west-1, once)

1. CloudWatch console → **Omni** → set up → **Account domain**.
2. Domain name, e.g. `my-lab`. Your sign-in URL becomes `https://my-lab.cloudwatch-omni.global.app.aws`.
3. Let the wizard create its IAM roles.
4. Space name `shop-lab`, account and Region eu-west-1.
5. Turn on **OTel span ingestion (Transaction Search)** and **OTel metrics enrichment**.
6. Finish. Write down: the time the setup took, and whether the $1,000 / 30-day credit was applied.
7. Optional, but it's the heart of the article: **Amazon DevOps Agent**. Create an agent space with the same sign-in method, give its operator role `AIDevOpsAgentFullAccess`, and in Omni go to Settings → Integrations → Amazon DevOps Agent → Connect. Write down what it costs, or whether you couldn't find out.

Then run `./scripts/03-aws.sh` again. Transaction Search must say `CloudWatchLogs / ACTIVE` before you deploy.

## Step 1 – Is the pipeline correct? (after `04-deploy.sh` + 15 minutes)

`./scripts/05-verify.sh` must be all `[OK]`.

Then prove that **both worlds got the same data**. In Grafana Explore → Prometheus, over the same 15 minutes:

```promql
# spans the collector sent to each backend: must be equal for Tempo and CloudWatch
sum by (exporter) (increase({__name__=~"otelcol_exporter_sent_spans(_total)?"}[15m]))
# and nothing failed
sum by (exporter) (increase({__name__=~"otelcol_exporter_send_failed_.*"}[15m]))
# storefront requests in 15 minutes
sum(increase(lab_spanmetrics_calls_total{service_name="storefront", span_kind="SPAN_KIND_SERVER"}[15m]))
```

In Omni, read the same window for the service `storefront`: request count, error rate and p95.

| Check | Grafana | Omni | Same? |
|---|---|---|---|
| spans sent (collector) | otlp_grpc/tempo = | otlp_http/cw-traces = | |
| storefront requests (15 min) | | | |
| storefront error rate | | | |
| storefront p95 | | | |
| services on the map | | | |

If p95 differs, that's a finding, not a bug. Grafana interpolates inside histogram buckets (see the SkyWalking article). Write down both values.

Screenshots: `omni-application-map.png`, `grafana-service-graph.png`, `omni-service-storefront.png`, `grafana-red-dashboard.png`.

## Step 2 – Alerts on both sides (equal rules)

- **Grafana:** provisioned in Prometheus as `StorefrontErrorRateHigh` (per tenant > 5% for 1 min) and `StorefrontLatencyHigh` (p95 > 800 ms for 1 min). You see them in Grafana → Alerting → Alert rules (data source Prometheus).
- **Omni:** create the same two alerts in Omni → Alerts for the storefront service. Write down how long it took and whether you could split by tenant.

## Step 3 – Run 1: incident A (you know the cause, so time to detect only)

```bash
./incident/start.sh a
```

Mark every milestone:

```bash
./incident/mark.sh "grafana: StorefrontLatencyHigh pending"
./incident/mark.sh "grafana: firing"
./incident/mark.sh "omni: alert firing"
```

Then let Omni / DevOps Agent investigate. Paste its full answer into `run1-omni-answer.md`. Roll back with `./incident/stop.sh`. Wait 15 minutes.

## Step 4 – Run 2: blind (the real comparison)

```bash
./incident/start.sh blind
```

You don't know whether it's A or B. Don't open `incident/.answer`.

1. **Omni first** (otherwise you've already seen the answer in Grafana): on the firing alert choose **Investigate**, or type `/investigation new storefront errors and latency increased`. Don't help it. Mark when it gives its conclusion. Save the answer to `run2-omni-answer.md`.
2. **Grafana**, by hand: dashboard → Tempo → Loki. Time box 20 minutes. Mark each step: "found slow service", "found version", "found mechanism". Write down the steps you took. That list goes into the article.
3. `./incident/stop.sh` prints the right answer.

Honesty note for the article: in run 2 you investigated Grafana *after* reading Omni's answer, so your Grafana time is a lower bound. If you can, have a colleague do the Grafana side without seeing Omni.

## Scoring (the same for both sides)

| Criterion | 1 point if the answer contains it |
|---|---|
| Service | inventory (A) / payments (B) |
| Trigger | the new version (2.0.0 / 1.4.0) |
| Mechanism | cache misses → many Redis/DB calls (A) / synchronous fraud check (B) |
| Scope | only tenant-b (A) / only tenant-c (B) |
| Red herring | does NOT blame the "card network latency" warnings |

Also write down: time to detect, time to root cause, number of clicks/queries (Grafana), wrong leads (both).

## Step 5 – What it cost (next day)

- Cost Explorer, service CloudWatch, the day of the test: ingestion GB and $ (minus the credit).
- EKS lab: EC2 + EKS + NAT + LB for the hours it ran.
- The Grafana stack's own resources: `kubectl top pods -n observability` during the test.

## Results table (fill in, it's the core of the article)

| | Grafana stack (self-hosted) | CloudWatch Omni |
|---|---|---|
| Setup time | | |
| Data matches the collector (spans in/out) | | |
| Time to detect, run 1 | | |
| Time to detect, run 2 | | |
| Time to root cause, run 2 | | |
| Score (0–5), run 2 | | |
| Fell for the red herring? | | |
| Per-tenant view | | |
| Cost for the test day | | |
| What I had to run myself | Tempo, Loki, Prometheus, Grafana, alerting | collector only |
