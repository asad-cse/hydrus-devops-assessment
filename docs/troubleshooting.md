# Troubleshooting: High Latency + 503 + Pod Restart Scenario

## Q19. Possible Root Causes
1. Pod hitting CPU/memory limits → throttling or OOMKill
2. HPA min replica too low — traffic spikes not absorbed
3. Database connection pool exhausted (DB tuning issue)
4. Slow query / missing index — DB CPU pegged
5. Liveness probe failing intermittently → unnecessary restarts
6. Memory leak in the app — buildup recurs after each restart
7. Downstream service (DB / external API) slow → cascading timeouts
8. Node-level pressure from other workloads → eviction
9. Network policy / NSG drop → intermittent failures
10. Image pull issue on new pods
11. ConfigMap/Secret inconsistency — some pods running with wrong config

## Q20. Step-by-step Investigation

### Step 1 — Cluster overview
```bash
kubectl get nodes
kubectl top nodes
kubectl get pods -n hydrus -o wide
kubectl top pods -n hydrus
```

### Step 2 — Identify restarting pods
```bash
kubectl get pods -n hydrus --sort-by=.status.containerStatuses[0].restartCount
kubectl describe pod <pod> -n hydrus
kubectl logs <pod> -n hydrus --previous --tail=200
```

### Step 3 — Resource usage and throttling
```bash
kubectl top pod <pod> -n hydrus --containers
# Check CPU throttling in Prometheus/Grafana: container_cpu_cfs_throttled_seconds_total
```

### Step 4 — HPA status
```bash
kubectl get hpa -n hydrus
kubectl describe hpa backend-hpa -n hydrus
# Inspect current/desired replicas and last scale time
```

### Step 5 — Service / endpoints
```bash
kubectl get endpoints backend -n hydrus
# Verify endpoint count matches ready replica count
```

### Step 6 — Ingress / Load Balancer
```bash
kubectl get ingress -n hydrus
kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx --tail=200
# Determine whether 503s originate at backend or ingress
```

### Step 7 — Database
```bash
kubectl exec -it postgres-0 -n hydrus -- psql -U hydrus -d hydrus -c "SELECT * FROM pg_stat_activity;"
# Inspect slow queries, locks, connection count
```

### Step 8 — Application logs (KQL — Azure Container Insights)
```kql
ContainerLog
| where Namespace == "hydrus" and ContainerName == "backend"
| where TimeGenerated > ago(30m)
| where LogEntry contains "ERROR" or LogEntry contains "Timeout"
| project TimeGenerated, LogEntry
| order by TimeGenerated desc
```

### Step 9 — Node-level inspection (when SSH/debug access available)
```bash
kubectl debug node/<node> -it --image=busybox
# Inside the debug shell:
top
free -h
df -h
dmesg | tail -50           # OOM-killer logs
journalctl -u kubelet -n 200
```

## Q21. Commands Cheat-Sheet

**Kubernetes:**
```bash
kubectl get / describe / logs / top / exec / debug
kubectl rollout history / undo / restart deployment/<name>
kubectl get events --sort-by=.lastTimestamp -n hydrus
```

**Azure:**
```bash
az aks show -g <rg> -n <cluster>
az monitor metrics list --resource <aks-id> --metric "node_cpu_usage_percentage"
az aks nodepool list -g <rg> --cluster-name <cluster>
```

**Linux (node-level):**
```bash
top, htop, iotop
free -h, df -h, du -sh /var/log/*
ps aux | grep <proc>
ss -tnlp                   # listening ports
journalctl -u kubelet --since "10 min ago"
```

## Q22. Which logs and metrics to check first?
1. `kubectl describe pod` — Events section (immediate cause)
2. `kubectl logs --previous` (state before the crash)
3. Prometheus: `container_cpu_usage`, `container_memory_usage`, throttling, restart count
4. NGINX Ingress logs (source of 5xx responses)
5. Backend application error logs (via KQL in Azure Container Insights)
6. PostgreSQL slow queries / connection saturation
7. Node-level metrics — any resource pressure?

## Q23. Immediate Mitigation
- Increase HPA min replicas (2 → 4)
- Raise resource limits (CPU 500m → 1000m, memory 512Mi → 1Gi) if throttling is observed
- Roll back to last known stable version (`kubectl rollout undo`)
- Loosen liveness probe thresholds or add a startup probe
- Adjust DB connection pool size
- Apply ingress rate limiting (if abusive traffic detected)
- Manually evict failed pods

## Q24. Long-term Preventive Actions
1. Proper load testing (k6, Locust) before production deployment
2. Chaos engineering (Litmus, Chaos Mesh) — test pod kill, network delay, and failure scenarios
3. Distributed tracing (OpenTelemetry → Tempo / Application Insights) to identify bottlenecks
4. Database tuning — indexing, query analysis, read replicas
5. Connection pooling layer (PgBouncer)
6. Redis caching layer for hot data
7. CDN for frontend static assets
8. Multi-zone AKS node pools and HA database setup
9. Quarterly capacity planning and cost reviews
10. Define SLIs/SLOs/SLAs and track them in Grafana
11. Incident postmortem culture — extract learnings and action items from every incident
12. Continuous dashboard improvement and alert tuning (avoid alert fatigue)
