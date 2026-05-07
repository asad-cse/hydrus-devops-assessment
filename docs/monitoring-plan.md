# Monitoring and Logging Plan

## Goals
- Cluster + node health visibility
- Pod resource usage track
- API latency and error rate measure
- Production incident-এ alert

## Stack
| Layer | Tool |
|-------|------|
| Metrics scrape | Prometheus (kube-prometheus-stack via Helm) |
| Visualization | Grafana |
| Logs | Azure Monitor + Container Insights (oms_agent enabled by Terraform), or Loki |
| Alerting | Alertmanager (Prometheus) + Azure Monitor alerts |
| App-level traces | OpenTelemetry → Tempo/Application Insights |

## Install (Helm)

helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm install monitoring prometheus-community/kube-prometheus-stack \
  --namespace monitoring --create-namespace

## Show the dashboard key's
1. **Cluster Overview** — node CPU/memory, pod count, namespace usage
2. **Pod Resources** — per-pod CPU/mem/network
3. **API Latency** — FastAPI- `prometheus-fastapi-instrumentator` will add p50/p95/p99 latency, RPS, error rate and will get
4. **Ingress Traffic** — NGINX Ingress Controller default metrics
5. **HPA Behavior** — current/desired replicas

## Application Instrumentation
In this Backend- dependency will be added
- `prometheus-fastapi-instrumentator`
- `/metrics` endpoint expose will be — Prometheus scrape will do

## Alert Rules (Production)
| Alert | Threshold | Severity |
|-------|-----------|----------|
| Pod CrashLoopBackOff | restart > 3 in 10m | Critical |
| Backend API p95 latency | > 1s for 5m | Warning |
| Backend 5xx rate | > 5% over 5m | Critical |
| Node CPU usage | > 85% for 10m | Warning |
| Node memory pressure | available < 10% | Warning |
| HPA at max replicas | sustained 15m | Warning |
| Disk pressure | > 80% | Critical |
| PostgreSQL down | up == 0 for 1m | Critical |

## Channels
- Slack/Teams: warning + critical
- PagerDuty/SMS: critical only (off-hours)
- Email: daily digest

## Logging Strategy
- Application: structured JSON logs to stdout
- Container Insights via AKS oms_agent → Log Analytics workspace
- KQL queries example:
```kql
  ContainerLog
  | where TimeGenerated > ago(1h)
  | where Namespace == "hydrus"
  | where LogEntry contains "ERROR"
```
- Retention: 30 days hot, 90 days cold (cost-optimized)
