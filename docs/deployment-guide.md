# Hydrus DevOps Assessment — Deployment Guide and Q&A

This document consolidates the answers to assessment questions for Tasks 1–4.
Questions for Task 5 (incident investigation) are answered in
[`troubleshooting.md`](./troubleshooting.md).

---

## Task 1 — Dockerization

### Q1. What optimizations did you apply to reduce Docker image size?

Five primary techniques were applied:

1. **Multi-stage builds** — In the backend image, build tooling (`build-essential`,
   `libpq-dev`) lives only in the builder stage; only compiled wheels are copied
   into the runtime stage. The frontend image builds the React bundle in a Node
   stage and serves the static output from a minimal Nginx stage.
2. **Slim and Alpine base images** — `python:3.12-slim`, `node:20-alpine`,
   `nginx:1.27-alpine`, and `postgres:16-alpine` keep base layers small.
3. **`.dockerignore`** — `node_modules`, `dist`, `.git`, tests, virtualenvs, and
   markdown files are excluded from the build context.
4. **Cache cleanup in the same RUN layer** — `pip --no-cache-dir`, and
   `apt-get clean && rm -rf /var/lib/apt/lists/*` to avoid bloated layers.
5. **No dev dependencies in production** — `npm ci` for deterministic, lean
   installs; Python images contain only runtime requirements.

### Q2. What is the difference between a Docker image and a Docker container?

A Docker **image** is an immutable, read-only template — it consists of layered
filesystem snapshots, application code, dependencies, and metadata such as the
default command and exposed ports. An image, by itself, does not run.

A Docker **container** is a running instance of an image. It adds a thin
writable filesystem layer on top of the image, plus its own process tree,
network namespace, and resource limits. Many containers can be launched from
the same image, each isolated from the others.

### Q3. How do you pass environment-specific values to a container securely?

- **Local development** — values come from a `.env` file, which is in
  `.gitignore`. Only `.env.example` (with placeholder values) is committed.
- **Docker Compose** — values are injected through `environment:` blocks or
  `env_file:`.
- **Kubernetes** — non-sensitive values go in `ConfigMap`; sensitive values go
  in `Secret`. Pods consume them via `envFrom` or volume mounts.
- **Production best practice** — store secrets in **Azure Key Vault** and mount
  them with the **Secrets Store CSI Driver**, so secrets never sit as plain
  text in etcd. The External Secrets Operator is another solid pattern.
- **CI/CD** — Azure DevOps Variable Groups or GitHub Actions Secrets, injected
  as environment variables only at runtime, never written into source.

### Q4. How would you troubleshoot a container that exits immediately after startup?

```bash
docker ps -a                              # check exit code
docker logs <container_id>                # last error written before exit
docker inspect <id> --format '{{.State}}' # OOMKilled? non-zero exit?
docker run -it --entrypoint sh <image>    # interactive shell to inspect
```

Common causes worth checking:

- Wrong `ENTRYPOINT` or `CMD`
- Missing required environment variable causing the app to crash on boot
- Port already bound on the host
- A dependency (such as the database) not yet ready when the app starts
- File permission errors when running as a non-root user
- Missing system library (for example, `psycopg2` requires `libpq`)

---

## Task 2 — Terraform on Azure

### Q5. How would you manage separate dev, stage, and prod environments?

Three viable approaches:

1. **`tfvars` per environment with separate state keys** (the approach used in
   this project). The same Terraform code is reused, but `dev.tfvars`,
   `stage.tfvars`, and `prod.tfvars` provide environment-specific values, and
   each environment uses a distinct state key (e.g. `hydrus.dev.tfstate`,
   `hydrus.prod.tfstate`). Simple and easy to maintain.
2. **Terraform Workspaces** — multiple states under one backend. Convenient for
   quick experimentation, but a separate state file per environment is safer
   for production because workspaces share configuration.
3. **Per-environment backend configuration** — `terraform init -backend-config=...`
   switches the state path at init time.

For larger teams, tools such as **Terragrunt** or **Atlantis** add DRY and
automation patterns on top of these approaches.

### Q6. What is Terraform state, and why is remote state important?

The state file (`terraform.tfstate`) is Terraform's memory: it maps each HCL
resource block to the corresponding real Azure resource. Without it, Terraform
cannot compute a `plan` or detect drift.

Remote state is important because:

- **Team collaboration** — every engineer reads from and writes to the same
  source of truth.
- **State locking** — Azure Storage uses blob lease locking to prevent
  concurrent applies that would corrupt the state.
- **Backup and versioning** — enabling blob versioning on the storage account
  makes recovery trivial.
- **Security** — state may contain sensitive values; Azure Storage provides
  encryption at rest and access control.

### Q7. How would you secure Terraform state and sensitive variables?

- Encryption at rest (Azure Storage default) and TLS in transit
- Disable public access on the storage account; use a private endpoint
- RBAC limited to authorized service principals and operators
- Mark sensitive Terraform variables with `sensitive = true` so they are
  redacted from CLI output
- Keep real secrets out of `.tfvars` files; instead read them from Azure Key
  Vault via the `azurerm_key_vault_secret` data source, or inject them as
  environment variables (`TF_VAR_*`) from CI/CD secrets
- Never commit `terraform.tfstate` or `.tfvars` containing secrets — both are
  in `.gitignore`

### Q8. What Azure networking and security considerations would you apply for AKS?

- **Private cluster** — set `private_cluster_enabled = true` for production so
  the API server has no public endpoint
- **CNI choice** — Azure CNI (used here) gives pods VNet-routable IPs, which
  improves integration but requires careful IP planning. Kubenet is simpler but
  introduces an overlay network
- **NSG rules** on the AKS subnet to restrict ingress and egress
- **Workload Identity / Managed Identity** so pods access Azure resources
  without long-lived credentials
- **Azure Policy for AKS** to enforce constraints (deny privileged containers,
  hostPath volumes, etc.)
- **Network Policies** (Calico or Cilium) to control pod-to-pod traffic
- **Egress control** with Azure Firewall or user-defined routes
- **Image scanning** in ACR via Microsoft Defender for Containers
- **Secrets** stored in Azure Key Vault and surfaced through the Secrets Store
  CSI driver, never as plain etcd Secrets

---

## Task 3 — Kubernetes (AKS) Deployment

### Q9. Explain the request flow from browser to frontend to backend API inside AKS.

1. The user opens `https://hydrus.example.com` in the browser.
2. DNS resolves to the public IP of the NGINX Ingress controller (an Azure
   Standard Load Balancer).
3. The Azure Load Balancer forwards traffic to the NGINX Ingress controller
   pods.
4. The Ingress controller applies path-based routing — `/` is sent to the
   `frontend` Service, `/api` to the `backend` Service.
5. The frontend pod (Nginx) returns the static React bundle to the browser.
6. The React app, once loaded, calls `${VITE_API_BASE_URL}/api/items`. Because
   Ingress shares the host, this request returns to the same domain.
7. Ingress routes that request to the `backend` ClusterIP Service.
8. `kube-proxy` (via iptables or IPVS) forwards the request to one of the ready
   backend pods.
9. The FastAPI pod handles the request and queries PostgreSQL through the
   in-cluster `postgres:5432` Service.
10. The response travels back along the same path to the browser.

### Q10. What is the difference between a Deployment and a StatefulSet?

| Aspect        | Deployment                          | StatefulSet                              |
|---------------|-------------------------------------|------------------------------------------|
| Pod identity  | Random suffix, interchangeable      | Stable ordinal name (e.g., `postgres-0`) |
| Storage       | Shared/none, ephemeral by default   | Per-pod PersistentVolume via `volumeClaimTemplates` |
| Startup       | Parallel                            | Ordered (0 → 1 → 2)                      |
| Scaling       | Parallel                            | Sequential                               |
| Use case      | Stateless workloads (APIs, frontend)| Stateful workloads (DB, Kafka, ZooKeeper)|

### Q11. What is the difference between ClusterIP, NodePort, and LoadBalancer?

- **ClusterIP** (default) — a virtual IP reachable only inside the cluster,
  used for internal service-to-service communication.
- **NodePort** — exposes the service on a static port (30000–32767) on every
  node. Allows external access without a cloud LB but produces awkward URLs
  and requires per-node port management. Mostly used in development.
- **LoadBalancer** — provisions a cloud provider load balancer (Azure Standard
  LB) with a public IP. Excellent for external traffic, but per-service LBs
  are expensive at scale; production clusters typically front everything with
  a single Ingress controller of type LoadBalancer.

### Q12. How would you troubleshoot a pod stuck in CrashLoopBackOff?

```bash
kubectl describe pod <pod> -n hydrus           # inspect Events section
kubectl logs <pod> -n hydrus --previous        # logs from the crashed instance
kubectl logs <pod> -n hydrus -c <container>    # specific container in multi-container pods
kubectl get events -n hydrus --sort-by=.lastTimestamp
kubectl exec -it <pod> -n hydrus -- sh         # if the pod is briefly up, or use kubectl debug
```

Common causes:

- Application startup failure (missing config, DB unreachable)
- Image pull failure (auth issue, wrong tag)
- OOMKilled — visible in `kubectl describe pod`'s last state; raise resource
  limits or fix a memory leak in the app
- Misconfigured liveness probe (wrong path or port) causing healthy pods to
  be killed
- Failing init container
- Permission issue (non-root user, read-only filesystem)

### Q13. How do readiness and liveness probes improve reliability?

- **Readiness probe** — answers, "Am I ready to receive traffic?" When it
  fails, the pod is removed from the Service endpoints but is **not**
  restarted. This prevents traffic from reaching a pod that is still
  initializing (warming caches, opening DB connections).
- **Liveness probe** — answers, "Am I still alive?" When it fails, the kubelet
  restarts the container. This recovers automatically from deadlocks and other
  stuck states.
- **Startup probe** (often overlooked) — for slow-starting applications,
  liveness and readiness probes only begin once the startup probe passes,
  which avoids killing apps during long boot sequences.

Used together, they make rolling updates smooth (failing-readiness pods don't
serve traffic) and recover automatically from in-process failures (failing
liveness triggers restart).

### Q14. Which metrics did you use for HPA and why?

CPU utilization at 70% and memory at 80%. Reasoning:

- The FastAPI workload is mostly CPU-bound under load, so CPU is the natural
  primary signal.
- A 70% threshold leaves enough headroom to scale up before saturation absorbs
  a traffic spike.
- Memory acts as a secondary safeguard against leaks or unusually heavy
  payloads.
- For production, **custom metrics** via the Prometheus Adapter would be even
  better — `http_requests_per_second`, p95 request duration, or queue depth
  correlate more directly with user experience than CPU does.

---

## Task 4 — CI/CD Pipeline

### Q15. Explain CI vs CD.

- **CI (Continuous Integration)** — every commit triggers automated build,
  test, and lint. The goal is fast feedback and a never-broken main branch.
  The deliverable is a tested artifact (Docker image, JAR, etc.).
- **CD (Continuous Delivery)** — the tested artifact is automatically deployed
  to staging or UAT, but production deployment requires explicit approval.
- **CD (Continuous Deployment)** — one step further: production is deployed
  automatically too, with no manual gate. This requires strong test coverage
  and observability.

The pipeline implemented here is CI plus Continuous Delivery: deploys to
production are gated by GitHub Environment protection rules.

### Q16. How would you implement rollback for a failed deployment?

Three layers of defense:

1. **Kubernetes-native rollback** — `kubectl rollout undo deployment/backend
   -n hydrus` reverts to the previous ReplicaSet.
2. **Pipeline-level automation** — an `if: failure()` step (included in this
   workflow) calls `kubectl rollout undo` if the post-deploy smoke test fails.
3. **Image-tag pinning** — every deploy uses an immutable Git SHA tag (e.g.
   `hydrus-backend:abc123`) rather than `latest`, so rollback is deterministic
   and auditable.

For larger systems, **Argo Rollouts** or **Flagger** add progressive delivery
(canary or blue-green) with automatic rollback driven by metrics.

### Q17. What is the difference between rolling update and blue-green deployment?

- **Rolling update** (Kubernetes default) — old pods are gradually replaced
  with new ones. `maxSurge` and `maxUnavailable` control the pace. Resource
  efficient, but during the rollout traffic is served by mixed versions.
- **Blue-green** — a complete second environment ("green") is deployed
  alongside the existing "blue". Traffic is switched all at once by changing
  the load balancer or Service selector. Rollback is instant (switch back),
  but it doubles resource usage and complicates data migrations.
- **Canary** (a middle ground) — a small percentage of traffic (say, 5%) is
  routed to the new version; if metrics stay healthy, the share is gradually
  raised to 100%. Argo Rollouts is well-suited to this pattern.

### Q18. How would you protect secrets used by the pipeline?

- Store secrets in **GitHub Actions Secrets** or **Azure DevOps Variable
  Groups**; they are injected as environment variables at runtime only.
- Never echo secrets into workflow logs (GitHub auto-masks known secrets, but
  any transformation can leak them).
- Prefer **short-lived tokens via OIDC federation** (GitHub → Azure Workload
  Identity) over long-lived service principal secrets.
- Enforce **branch protection** so deploy jobs only run on `main`, gated by
  pull request review.
- Use **environment protection rules** (required reviewers) for production.
- Enable **secret scanning** on the repository so leaked secrets are
  auto-revoked.
- For Terraform, mark variables `sensitive = true` and source real secrets
  from Azure Key Vault rather than committing them.

---

## Reference

- Task 5 incident investigation, root causes, and runbook — see
  [`troubleshooting.md`](./troubleshooting.md).
- Monitoring and alerting plan — see [`monitoring-plan.md`](./monitoring-plan.md).
- Local development, infrastructure, and deployment commands — see the root
  [`README.md`](../README.md).
