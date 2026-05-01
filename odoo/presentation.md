# Odoo Helm Chart — Technical Presentation

**Chart**: `odoo` v5.3.9  
**Maintainer**: Camptocamp  
**Target platform**: Azure Kubernetes Service (AKS)

---

## 1. Overview

This Helm chart deploys a production-grade Odoo ERP instance on AKS. It is opinionated, Azure-first, and integrates tightly with the Camptocamp platform tooling.

Key design pillars:

- **Multi-container pods** — Odoo is never alone; nginx and a health sidecar always run beside it
- **Migration-safe deployments** — init containers coordinate DB migrations before any Odoo process starts
- **Traefik-native ingress** — no standard Kubernetes Ingress; only Traefik CRDs
- **Instance sizing profiles** — three tiers (`standard`, `large`, `xlarge`) drive both K8s resources and Odoo internal limits
- **Lab isolation** — multiple instances can coexist in the same namespace using a `lab_name` suffix

---

## 2. Chart Structure

```
odoo/
├── Chart.yaml                        Chart metadata (v5.3.9)
├── values.yaml                       Default configuration
└── templates/
    ├── _helpers.tpl                  Core naming & shared env helpers
    ├── _config_odoo_helpers.tpl      ConfigMap content generator
    ├── _deployment_helpers.tpl       Deployment & Service generator
    ├── _quotas_worker_helpers.tpl    Resource sizing — worker
    ├── _quotas_thread_helpers.tpl    Resource sizing — thread
    ├── _quotas_cron_helpers.tpl      Resource sizing — cron
    ├── _quotas_queuejob_helpers.tpl  Resource sizing — queuejob
    ├── deployment.yaml               Top-level deployment dispatcher
    ├── config-odoo.yaml              Emits ConfigMaps per pod type
    ├── config-odoo-queue.yaml        ConfigMap for queuejob
    ├── config-odoo-secret.yaml       Optional Secret resource
    ├── config-odoo-healthz.yaml      ConfigMap for odoohealthz sidecar
    ├── config-odoo-preinit-manager.yaml  ConfigMap for migration gate
    ├── config-nginx.yaml             ConfigMap for nginx sidecar
    ├── ingressRoutes.yaml            Traefik IngressRoute CRDs
    ├── middleware.yaml               Per-route Traefik Middleware CRDs
    ├── defaultMiddleware.yaml        Default/shared Traefik Middleware CRDs
    ├── certificates.yaml             cert-manager Certificate CRDs
    ├── networkPolicies.yaml          NetworkPolicy
    ├── servicemonitor.yaml           Prometheus ServiceMonitor CRD
    ├── podDisruptionBudget.yaml      PodDisruptionBudget
    └── rbac.yaml                     RoleBinding resources
```

---

## 3. Deployment Modes

The chart supports two operating modes, controlled by `odoo.mode`.

### 3.1 `workers` mode (default)

```
┌──────────────────────────────────────────┐
│  Deployment: <name>-worker               │
│                                          │
│  [init] marabunta-setup                  │
│  [init] preinit-manager  (MUST_BACKUP)   │
│  [init] marabunta-migration              │
│                                          │
│  [container] odoo        :8069 / :8072   │
│  [container] nginx       :80             │
│  [container] odoohealthz :8080           │
└──────────────────────────────────────────┘
```

A single deployment handles HTTP requests, cron jobs, and longpolling.

### 3.2 `hybrid` mode

```
┌─────────────────────────────────────────┐   ┌──────────────────────────────────────────┐
│  Deployment: <name>-thread              │   │  Deployment: <name>-cron                 │
│                                         │   │                                          │
│  [init] marabunta-setup                 │   │  [init] marabunta-setup                  │
│  [init] preinit-manager (MUST_ONLY_WAIT)│   │  [init] preinit-manager  (MUST_BACKUP)   │
│                                         │   │  [init] marabunta-migration              │
│  ODOO_MAX_HTTP_THREADS=True             │   │  CRON_POD=True                           │
│  WORKERS=0  (threaded mode)             │   │                                          │
│                                         │   │  [container] odoo                        │
│  [container] odoo                       │   │  [container] nginx                       │
│  [container] nginx                      │   │  [container] odoohealthz                 │
│  [container] odoohealthz                │   └──────────────────────────────────────────┘
└─────────────────────────────────────────┘
```

HTTP traffic and cron are handled by separate deployments, allowing independent scaling.

### 3.3 Queue Job deployment (optional, both modes)

When `odoo.queuejob.enabled: true`, a third independent Deployment is always created:

```
┌──────────────────────────────────────────────────────┐
│  Deployment: <name>-queuejob                         │
│                                                      │
│  [init] wait-for-odoo  (polls /web/login until 200)  │
│                                                      │
│  [container] odooqueue  --load=...,queue_job         │
│  [container] odoohealthz  /queue_liveness            │
└──────────────────────────────────────────────────────┘
```

---

## 4. Pod Architecture

Every main Odoo pod is a **multi-container pod**:

```
┌─────────────────────────────────────────────────────────────────┐
│  Pod                                                            │
│                                                                 │
│  ┌──────────────────┐  ┌─────────────┐  ┌──────────────────┐  │
│  │   odoo           │  │   nginx     │  │   odoohealthz    │  │
│  │   :8069 (http)   │◄─│   :80       │  │   :8080          │  │
│  │   :8072 (poll)   │  │  (reverse   │  │  /liveness       │  │
│  │                  │  │   proxy +   │  │  /readiness      │  │
│  │  Odoo process    │  │   static    │  │  /metrics        │  │
│  │                  │  │   assets)   │  │  /queue_liveness │  │
│  └──────────────────┘  └─────────────┘  └──────────────────┘  │
│                                                                 │
│  All health probes target odoohealthz:8080                      │
│  All external traffic enters through nginx:80                   │
└─────────────────────────────────────────────────────────────────┘
```

| Container | Image | Port | Purpose |
|-----------|-------|------|---------|
| `odoo` | `ghcr.io/camptocamp/customer_odoo` | 8069, 8072 | Odoo application server |
| `nginx` | `camptocamp.azurecr.io/odoo/odoo-nginx` | 80 | Reverse proxy, static assets, longpolling routing |
| `odoohealthz` | `camptocamp.azurecr.io/odoo/odoo-k8s-healthz` | 8080 | Health checks & Prometheus metrics |

---

## 5. Init Container Chain (Migration Gate)

When `odoo.marabunta.enabled: true`, every pod runs three init containers in sequence before the main containers start.

```
[1] marabunta-setup
    └─ Copies /odoo/migration.yml → emptyDir /tmp
       (reads migration spec from the Odoo image itself)

[2] preinit-manager
    └─ Contacts Celebrimbor service to check migration eligibility
    └─ On prod env: sets MUST_BACKUP=true  (for cron/worker types)
    └─ For thread/queuejob:  sets MUST_ONLY_WAIT=true (wait for migration, don't run it)
    └─ Acts as a distributed migration gate across all pods

[3] marabunta-migration       ← only for cron and worker pod types
    └─ Runs the actual DB migration using the migration.yml file
    └─ Uses `gosu odoo migrate` (old images) or `migrate` (new images)
```

This ensures:
- Only one pod type runs the migration
- Other pods wait until migration completes
- A backup is triggered before any destructive migration on production

---

## 6. Resource Sizing

Controlled by `odoo.instance_type`. Sizes configure both **Odoo-internal** env vars and **Kubernetes** physical resources.

### 6.1 Worker / Thread pod (HTTP-facing)

| Profile | K8s CPU limit | K8s Mem limit | `WORKERS` | `LIMIT_MEMORY_SOFT` | `LIMIT_MEMORY_HARD` |
|---------|--------------|--------------|-----------|--------------------|--------------------|
| `standard` | 1 | 2.2 Gi | 7 | 650 MB | 2 GB |
| `large` | 2 | 3 Gi | 14 | 650 MB | 4 GB |
| `xlarge` | 4 | 3.5 Gi | 14 | 650 MB | 4 GB |

Thread mode always sets `WORKERS=0` (Odoo threaded mode) and has lower memory limits.

### 6.2 Cron pod

| Profile | K8s CPU limit | K8s Mem limit | `WORKERS` | `LIMIT_MEMORY_SOFT` | `LIMIT_MEMORY_HARD` |
|---------|--------------|--------------|-----------|--------------------|--------------------|
| `standard` | 1 | 2 Gi | 1 | 750 MB | 2 GB |
| `large` | 2 | 3 Gi | 1 | 1 GB | 2.5 GB |
| `xlarge` | 4 | 3.5 Gi | 2 | 1.5 GB | 3 GB |

### 6.3 QueueJob pod

| Profile | K8s CPU limit | K8s Mem limit | `WORKERS` | `DB_MAXCONN` |
|---------|--------------|--------------|-----------|-------------|
| `standard` | 1 | 2 Gi | 3 | 5 |
| `large` | 2 | 3 Gi | 5 | 5 |
| `xlarge` | 4 | 3.5 Gi | 7 | 5 |

All sizes can be overridden at any granularity via `odoo.override_resources` and `odoo.override_limits`.

---

## 7. Configuration System

### 7.1 ConfigMaps per pod type

Each pod type gets a dedicated ConfigMap carrying Odoo env vars:

```
odoo-config[-<lab>]-worker
odoo-config[-<lab>]-thread
odoo-config[-<lab>]-cron
odoo-config[-<lab>]-queuejob
```

Generated by the `odoo.config` named template (`_config_odoo_helpers.tpl`), dispatching resource values based on `pod_type`.

Key env vars configured:

| Variable | Source |
|----------|--------|
| `ODOO_BASE_URL` / `ODOO_REPORT_URL` | `odoo.base_url`, `odoo.report_url` |
| `AZURE_STORAGE_*` | `odoo.storage` (3 auth modes: AAD / connection string / account key) |
| `WORKERS`, `LIMIT_MEMORY_SOFT/HARD` | Instance type + pod type quotas |
| `DB_MAXCONN`, `MAX_CRON_THREADS` | Instance type + pod type quotas |
| `SERVER_WIDE_MODULES` | Version-aware: differs between Odoo ≤17 and ≥18 |
| `MARABUNTA_MODE`, `MIGRATE` | `odoo.marabunta` values |
| `ODOO_SESSION_REDIS_URL` | `odoo.redis.enabled` |
| `LOG_HANDLER`, `LOG_LEVEL` | `odoo.log_handler`, `odoo.log_level` |
| `ODOO_QUEUE_JOB_CHANNELS` | `odoo.queuejob.channels` (queuejob only) |

### 7.2 Config-change-triggered restarts

Every Deployment embeds sha256 annotations of its ConfigMaps:

```yaml
annotations:
  config-hash-odoo:    "{{ sha256sum (include "odoo.config" ...) }}"
  config-hash-nginx:   "{{ sha256sum (include "nginx-config" ...) }}"
  config-hash-secret:  "{{ sha256sum (include "odoo-secret" ...) }}"
  config-hash-healthz: "{{ sha256sum (include "odoohealthz-config" ...) }}"
```

Any `helm upgrade` that changes a ConfigMap value automatically triggers a rolling pod restart.

### 7.3 Pre-existing Secrets

The chart expects these secrets to exist before deployment:

| Secret | Contents |
|--------|----------|
| `odoo-database` | `host`, `user`, `password`, `database`, port |
| `odoo-storage` | Azure Blob Storage container name |
| `odoo-redis` | Redis URL (when `odoo.redis.enabled: true`) |
| `github-packages` | Image pull secret for GHCR |
| `odoo-secret` | Optional arbitrary Odoo env overrides |

---

## 8. Odoo Version Awareness

The chart explicitly handles differences between Odoo versions:

```
odoo_version > 17.0  →  SERVER_WIDE_MODULES = "session_redis,logging_json"
                         (Azure attachment handling moved to Odoo core in v18)

odoo_version ≤ 17.0  →  SERVER_WIDE_MODULES = "attachment_azure,session_redis,logging_json"
                         (Azure filestore requires the attachment_azure addon)

is_old_image_flavour = True  →  entrypoint: gosu odoo odoo ...
is_old_image_flavour = False →  entrypoint: odoo ...
```

---

## 9. Ingress — Traefik CRDs

The chart uses **no standard Kubernetes Ingress**. All routing uses Traefik v3 CRDs.

### 9.1 Route structure

```yaml
ingressRoutes:
  routes:
    - hostList:
        - hosts: [myodoo.example.com]
          certificate:
            useDefault: false
            issuerRef: letsencrypt-prod
          paths:
            - list:
                - path: /
                  type: prefix   # prefix | specific | regex
              component: thread  # override default target service
              middlewares:
                ipAllowList:
                  useDefault: false
                  override:
                    sourceRange: [10.0.0.0/8]
```

### 9.2 Resource naming

All Middleware and IngressRoute names are derived from **SHA1 hashes** of their parameters (host list, path list), ensuring stable and collision-free naming across chart upgrades:

```
IngressRoute: odoo-ingress-<sha1(hosts)>
Certificate:  crt-<sha1(hosts)>
TLS Secret:   sct-<sha1(hosts)>
Middleware:   mw-ip-<hash>   mw-wf-<hash>   mw-rn-<hash>
              mw-rl-<hash>   mw-rs-<hash>   mw-rr-<hash>
              mw-retry-<hash>
```

### 9.3 Middleware types

Every route always gets the `mw-hs-security` middleware (HSTS: `stsSeconds: 31536000`, `stsIncludeSubdomains`, `stsPreload`).

Additional per-route middlewares (default or per-path override):

| Key | Middleware type | Purpose |
|-----|----------------|---------|
| `ipAllowList` | `ipAllowList` | Source IP restriction |
| `waf` | `forwardAuth` | External WAF service |
| `robotNoIndex` | `headers` | `X-Robots-Tag: noindex` |
| `rateLimits` | `rateLimit` | Traefik rate limiting |
| `redirectScheme` | `redirectScheme` | HTTP → HTTPS redirect |
| `redirectRegex` | `redirectRegex` | URL rewriting |
| `retry` | `retry` | Request retry on failure |
| `externalMiddlewares` | — | Reference external Middleware resources |

---

## 10. Naming Convention

All Kubernetes resource names follow a consistent pattern:

```
Standard environment:
  <customerName>-odoo-<env>
  e.g.: acme-odoo-prod, acme-odoo-integration

Labs environment (env == "labs"):
  <customerName>-odoo-<lab_name>
  e.g.: acme-odoo-lab01

ConfigMap / Secret suffix:
  Standard: odoo-config-worker
  Labs:     odoo-config-<lab_name>-worker
```

This allows multiple lab instances to coexist safely in the same namespace.

---

## 11. Network Policies

Always enabled by default (`networkPolicies.enabled: true`).

Allowed ingress sources:

| Source | Namespace selector |
|--------|--------------------|
| Traefik | `traefik` |
| Prometheus | `kube-prometheus-stack` |
| kwkhtmltopdf (PDF rendering) | `bs-kwkhtmltopdf01250`, `bs-kwkhtmltopdf01261`, `bs-kwkhtmltopdflog` |
| QueueJob pods (intra-namespace) | pods with label `queuejob: "true"` |
| Custom sources | `networkPolicies.extraFrom` |

---

## 12. Observability

### Prometheus

When `serviceMonitor.enabled: true`, a `ServiceMonitor` CRD is created targeting the `<fullname>-metrics` Service (port 8080). All metrics are exposed by the `odoohealthz` sidecar at `/metrics`.

Default scrape interval: `15s` (configurable via `odoo.metrics.scrapeInterval`).

### Health checks

All health probes route through `odoohealthz` on port 8080:

| Probe | Path | Used by |
|-------|------|---------|
| Liveness | `/liveness` | Main pods |
| Readiness | `/readiness` | Main pods |
| Liveness | `/queue_liveness` | QueueJob pod |

The `odoohealthz` sidecar can be configured to check:
- Stuck jobs
- Long-running transactions
- Expired DB
- Memory limit proximity

---

## 13. Update Strategy

| Condition | Strategy |
|-----------|----------|
| Default | `Recreate` (safe for DB-migration workflows) |
| `rollingupdatechart: true` | `RollingUpdate` |
| Image tag ends with `-roll` | `RollingUpdate` |

`revisionHistoryLimit: 3` on all Deployments.

---

## 14. Pod Scheduling

### Topology spread

When `spreadOdooPodsOverNodes.enabled: true` (default):

```yaml
topologySpreadConstraints:
  - maxSkew: 1
    topologyKey: kubernetes.io/hostname
    whenUnsatisfiable: ScheduleAnyway
```

Pods are spread across nodes on a best-effort basis.

### Component separation (hybrid mode)

When `separateOdooComponents: true` and `mode: hybrid`, each pod type gets a dedicated node via node labels:

```
thread pods  → node label: odoo.camptocamp.com/component-thread: "true"
cron pods    → node label: odoo.camptocamp.com/component-cron: "true"
queuejob     → node label: odoo.camptocamp.com/component-queuejob: "true"
```

---

## 15. RBAC

Two mechanisms:

1. **Custom RoleBindings** — `roleBindings` map allows arbitrary role bindings to be declared in values
2. **BS Team power user** — when `bsTeamPowerUserGroupId` is set, the Azure AD group is bound to the `pod-exec` ClusterRole, enabling production debugging access (kubectl exec)

---

## 16. Template Architecture

The chart makes heavy use of Helm named templates (`define`/`include`) to avoid duplication.

Key pattern — context injection for pod type:

```go
{{- include "odoo.deployment" (merge (. | deepCopy) (dict "pod_type" "thread")) }}
```

This passes the root context with an injected `pod_type` key, enabling a single `_deployment_helpers.tpl` template to generate correctly differentiated Deployments for all pod types without mutating the root scope.

Resource dispatching by pod type:

```go
{{- if eq .pod_type "cron" }}
  {{- include "odoo.internal-resources-cron" . }}
{{- else if eq .pod_type "thread" }}
  {{- include "odoo.internal-resources-thread" . }}
{{- else if eq .pod_type "queuejob" }}
  {{- include "odoo.internal-resources-queuejob" . }}
{{- else }}
  {{- include "odoo.internal-resources-worker" . }}
{{- end }}
```

---

## 17. Azure Integration

The chart is designed exclusively for Azure/AKS:

| Feature | Azure service |
|---------|--------------|
| Container images (internal) | Azure Container Registry (`camptocamp.azurecr.io`) |
| Container images (customer) | GitHub Container Registry (`ghcr.io`) |
| Odoo filestore | Azure Blob Storage (`attachment_azure` / native v18) |
| DB migrations backup | Azure Key Vault (via Workload Identity, managed by Celebrimbor) |
| Pod identity | Azure Workload Identity |
| Database | Azure Database for PostgreSQL (Flexible Server) |

Three Azure Blob Storage authentication modes are supported:

| Mode | Values key | Mechanism |
|------|-----------|-----------|
| AAD (recommended) | `odoo.storage.use_aad: true` | Workload Identity → Managed Identity |
| Connection string | `odoo.storage.connection_string` | SAS / connection string in secret |
| Account key | `odoo.storage.account_name` + `account_key` | Storage account key |

---

## Summary

```
                    ┌─────────────────────────────────────────────────────┐
                    │              Traefik IngressRoute                   │
                    │  Middleware chain (HSTS, IP, WAF, rate limit, ...)  │
                    └───────────────────────┬─────────────────────────────┘
                                            │
                          ┌─────────────────┼──────────────────┐
                          ▼                 ▼                  ▼
                   worker/thread         cron            queuejob
                   Deployment          Deployment        Deployment
                          │                 │                  │
                   ┌──────┴──────┐   ┌──────┴──────┐  ┌───────┴──────┐
                   │ init chain  │   │ init chain  │  │ wait-for-odoo│
                   │ (migration) │   │ (migration) │  └──────────────┘
                   ├─────────────┤   ├─────────────┤
                   │ odoo        │   │ odoo        │
                   │ nginx       │   │ nginx       │
                   │ odoohealthz │   │ odoohealthz │
                   └──────┬──────┘   └──────┬──────┘
                          │                 │
                          └────────┬────────┘
                                   │
              ┌────────────────────┼────────────────────┐
              ▼                    ▼                     ▼
       Azure PostgreSQL     Azure Blob Storage    Redis (sessions)
       (via Odyssey          (filestore)          (optional)
        pooler)
```

The chart provides a complete, self-contained, production-ready Odoo deployment with built-in migration coordination, observability, ingress management, and multi-tenant lab support — all within a single Helm chart.

---

## 18. File Reference — Complete Description of Every File

### Root-level files

---

#### `Chart.yaml`

**Type**: Helm metadata  
**Role**: Declares the chart identity to Helm. Contains the chart name (`odoo`), description, type (`application`), and version (`5.3.9`). This file is mandatory for any Helm chart; without it the chart cannot be packaged or installed. The `apiVersion: v2` field marks this as a Helm 3 chart.

```yaml
apiVersion: v2
name: odoo
description: A Helm chart to deploy Odoo on CampToCamp own platform
type: application
version: 5.3.9
```

---

#### `values.yaml`

**Type**: Default configuration  
**Role**: The single source of truth for all configurable parameters. Every template in the chart reads from this file via `.Values.*`. It defines defaults for all settings — images, resource sizing, deployment mode, ingress routes, migration config, Redis, Azure storage, health checks, network policies, and more. Operators override specific values using `-f my-values.yaml` at install/upgrade time.

Key top-level sections:

| Section | Purpose |
|---------|---------|
| `replicaCount` | Base replica count for main deployment |
| `image.*` | All container image references (odoo, nginx, odoohealthz, preinit_manager, curl) |
| `resources.*` | Fixed resource specs for sidecar containers (nginx, odoohealthz) |
| `odoo.*` | All Odoo-specific settings: mode, version, instance type, storage, DB, Redis, marabunta, cron, queuejob |
| `nginx.*` | Nginx sidecar configuration (upstream host, longpolling port, cache) |
| `odoohealthz.*` | Health check sidecar parameters (timeouts, enabled checks, memory limits) |
| `preinit_manager.*` | Migration gate configuration (Azure Key Vault, Celebrimbor service URL) |
| `ingressRoutes.*` | Traefik IngressRoute and Middleware definitions |
| `networkPolicies.*` | NetworkPolicy settings |
| `serviceMonitor.*` | Prometheus ServiceMonitor toggle |
| `spreadOdooPodsOverNodes.*` | Pod topology spread constraints |
| `roleBindings` / `bsTeamPowerUserGroupId` | RBAC configuration |
| `podDisruptionBudget` | PDB min/max availability settings |
| `volumes` / `volumeMounts` | Extra volumes injected into odoo and queuejob containers |

---

#### `README.md`

**Type**: Documentation  
**Role**: Human-readable reference for operators. Documents prerequisites (Kubernetes version, required secrets, external controllers), deployment modes, all Kubernetes resources created by the chart, and a full values reference table. Does not affect chart rendering in any way.

---

#### `.helmignore`

**Type**: Packaging exclusion list  
**Role**: Tells `helm package` which files to exclude from the `.tgz` archive. Excludes OS artefacts (`.DS_Store`), VCS directories (`.git/`, `.svn/`), editor files (`.vscode/`, `.idea/`), and common backup/temp file patterns (`*.swp`, `*.bak`, `*.tmp`). Has no effect at install or render time — only relevant when building chart archives.

---

#### `index.yaml`

**Type**: Helm repository index (local, empty)  
**Role**: An empty Helm repository index stub local to this chart subdirectory. The real repository index lives at the root of `odoo-platform-charts/`. This file has no functional role at chart install or render time.

---

### `templates/` — Named template files (helpers, prefixed with `_`)

Files prefixed with `_` are never rendered directly as Kubernetes manifests. They define reusable named templates consumed via `include` from other template files.

---

#### `templates/_helpers.tpl`

**Type**: Named template library  
**Role**: Defines the core naming and shared environment helper templates used by every other template in the chart.

Named templates defined:

| Template | Purpose |
|----------|---------|
| `odoo.name` | Builds `<customerName>-odoo-<env>` or `<customerName>-odoo-<lab_name>` when `env == "labs"`. Used as the base name for Deployments, Services, and NetworkPolicy. |
| `odoo.fullname` | Standard Helm fullname with 63-char truncation. Respects `fullnameOverride` and `nameOverride`. Used for Service names and IngressRoute service targets. |
| `odoo.chart` | Returns `<chart>-<version>`, used in the `helm.sh/chart` label. |
| `odoo.labels` | Emits the full standard Helm label set plus optional `extraLabels`. Applied to every resource's `metadata.labels`. |
| `odoo.selectorLabels` | Emits only `app.kubernetes.io/name` and `app.kubernetes.io/instance`. Used in Deployment selectors and Service selectors to match pods. |
| `odoo-cs-suffix` | Returns `-<lab_name>` when `env == "labs"`, empty string otherwise. Appended to all ConfigMap and Secret names to enable namespace-level multi-tenancy for lab environments. |
| `odoo.common-environment` | Emits the set of env vars shared across every Odoo-related container: `AZURE_STORAGE_NAME`, `DB_HOST`, `DB_NAME`, `DB_USER`, `DB_PASSWORD`, `DB_PORT`, and optionally `ODOO_SESSION_REDIS_URL`. All values are read from Kubernetes Secrets via `secretKeyRef`. |
| `odoo.component-limits` | Emits six Odoo runtime limit env vars (`LIMIT_REQUEST`, `LIMIT_TIME_CPU`, `LIMIT_TIME_REAL`, `LIMIT_TIME_REAL_CRON`, `MAX_CRON_THREADS`, `DB_MAXCONN`) from a passed `compo` dict with configurable defaults. |

---

#### `templates/_config_odoo_helpers.tpl`

**Type**: Named template library  
**Role**: Defines the `odoo.config` named template, which generates the full content of an Odoo ConfigMap for a given pod type. It is the single place where all Odoo environment variables are assembled.

The template is called with an injected `pod_type` key (`worker`, `thread`, `cron`, or `queuejob`) and dispatches:
- **Azure storage** env vars: three mutually exclusive branches depending on whether AAD (`use_aad`), connection string, or account key authentication is configured
- **Internal resource env vars** (`WORKERS`, `LIMIT_MEMORY_SOFT`, `LIMIT_MEMORY_HARD`): dispatched to the appropriate `odoo.internal-resources-*` quota template based on `pod_type`
- **`SERVER_WIDE_MODULES`**: version-aware logic — for Odoo ≥18.0 the `attachment_azure` module is omitted (moved to core); for the `queuejob` pod type, `,queue_job` is appended
- **Component limits** (`DB_MAXCONN`, `MAX_CRON_THREADS`, etc.): dispatched via `odoo.component-limits` with per-pod-type defaults (`max_conn: 20` for cron/thread, `5` for worker/queuejob; `max_cron: 2` for cron, `1` for worker, `0` for thread/queuejob)
- **All other vars**: `ODOO_BASE_URL`, `ODOO_REPORT_URL`, `DEMO`, `MARABUNTA_MODE`, `MARABUNTA_ALLOW_SERIE`, `MIGRATE`, `ODOO_CLOUD_PLATFORM_UNSAFE`, `ODOO_LOGGING_JSON`, `RUNNING_ENV`, `LOG_HANDLER`, `LOG_LEVEL`, `UNACCENT`, `KWKHTMLTOPDF_SERVER_URL`, `PGCLIENTENCODING`, and optionally `ODOO_SESSION_REDIS`, `ODOO_SESSION_REDIS_PREFIX`, `ODOO_QUEUE_JOB_CHANNELS`

---

#### `templates/_deployment_helpers.tpl`

**Type**: Named template library  
**Role**: Defines the main `odoo.deployment` named template, which generates a complete `Deployment` resource and its associated `Service` for a given pod type. It is the most complex file in the chart.

Named templates defined:

| Template | Purpose |
|----------|---------|
| `odoo.deployment.replicas` | Returns the correct replica count: `odoo.cron.defaultReplicaCount` for cron, `odoo.queuejob.defaultReplicaCount` for queuejob, `replicaCount` otherwise, or `0` if `replicaCount` is falsy. |
| `odoo.deployment.defaultComponent` | Returns `worker` (mode=workers) or `thread` (mode=hybrid). Used by `ingressRoutes.yaml` to determine which Service an IngressRoute should target when no explicit `component` is set on a path. |
| `odoo.deployment` | Generates a full `Deployment` + `Service` pair for one pod type. |

Key logic inside `odoo.deployment`:

- **Update strategy**: `RollingUpdate` if the Odoo image tag ends with `-roll` or `rollingupdatechart: true`; otherwise `Recreate`
- **Config-hash annotations**: sha256 hashes of four ConfigMap templates are embedded as pod annotations — any ConfigMap change triggers automatic pod restarts on `helm upgrade`
- **Init containers** (when `marabunta.enabled`):
  - `marabunta-setup`: copies `migration.yml` from the Odoo image into the `marabunta-tmp` shared `emptyDir` volume
  - `preinit-manager`: contacts Celebrimbor; sets `MUST_BACKUP=true` for `cron`/`worker` on prod, `MUST_ONLY_WAIT=true` for `thread`/`queuejob`
  - `marabunta-migration`: runs the DB migration — only created for `cron` and `worker` pod types; uses `gosu odoo migrate` for old image flavour, `migrate` for new
- **Main containers**:
  - `odoo`: sets `CRON_POD=True` for cron type, `ODOO_MAX_HTTP_THREADS=True` for thread type; resources dispatched to `odoo.physical-resources-cron/thread/worker`
  - `nginx`: reads from `nginx-config` ConfigMap; fixed resources from `resources.nginx`
  - `odoohealthz`: reads from both the pod-type ConfigMap and `odoohealthz-config`; fixed resources from `resources.odoohealthz`
- **Volumes**: always creates `marabunta-tmp` emptyDir; merges `volumes.odoo` from values
- **Node scheduling**: `nodeSelector` with component-specific labels when `separateOdooComponents && hybrid`; supports `affinity` and `tolerations`; `topologySpreadConstraints` when `spreadOdooPodsOverNodes.enabled`
- **Service**: ClusterIP, port 80 → `http`, selector includes `app.kubernetes.io/component: odoo-<pod_type>`

---

#### `templates/_quotas_worker_helpers.tpl`

**Type**: Named template library  
**Role**: Defines resource sizing for the `worker` pod type.

| Template | Purpose |
|----------|---------|
| `odoo.internal-resources-worker` | Emits `WORKERS`, `LIMIT_MEMORY_SOFT`, `LIMIT_MEMORY_HARD` env vars for the worker ConfigMap, scaled by `instance_type`. Supports override via `override.workers`, `override.memory_soft`, `override.memory_hard`. |
| `odoo.physical-resources-worker` | Emits the `resources:` block (requests + limits for CPU and memory) for the `odoo` container in worker pods, scaled by `instance_type`. CPU and memory limits support `odoo.override_resources.cpu` and `odoo.override_resources.memory`. |

Values by instance type:

| Profile | `WORKERS` | `LIMIT_MEMORY_HARD` | CPU limit | Mem limit |
|---------|-----------|--------------------|-----------|-----------| 
| `standard` | 7 | 2 GB | 1 | 2.2 Gi |
| `large` | 14 | 4 GB | 2 | 3 Gi |
| `xlarge` | 14 | 4 GB | 4 | 3.5 Gi |

---

#### `templates/_quotas_thread_helpers.tpl`

**Type**: Named template library  
**Role**: Defines resource sizing for the `thread` pod type (hybrid mode HTTP-handling deployment).

| Template | Purpose |
|----------|---------|
| `odoo.internal-resources-thread` | Emits `WORKERS: "0"` (always — thread mode uses Odoo's threaded server, not multi-process workers), plus `LIMIT_MEMORY_SOFT` and `LIMIT_MEMORY_HARD` scaled by `instance_type`. |
| `odoo.physical-resources-thread` | Emits the `resources:` block for thread pods. Memory limits are lower than worker because threads do not each hold a full Odoo process in memory. |

Values by instance type:

| Profile | `WORKERS` | `LIMIT_MEMORY_HARD` | CPU limit | Mem limit |
|---------|-----------|--------------------|-----------|-----------| 
| `standard` | 0 | 900 MB | 1 | 1.2 Gi |
| `large` | 0 | 1.5 GB | 2 | 1.5 Gi |
| `xlarge` | 0 | 2 GB | 4 | 2 Gi |

---

#### `templates/_quotas_cron_helpers.tpl`

**Type**: Named template library  
**Role**: Defines resource sizing for the `cron` pod type (hybrid mode scheduled-job deployment, or the cron threads running inside the worker pod in workers mode).

| Template | Purpose |
|----------|---------|
| `odoo.internal-resources-cron` | Emits `WORKERS` (1 or 2 depending on size), `LIMIT_MEMORY_SOFT`, `LIMIT_MEMORY_HARD`. Uses `odoo.cron.override_limits` for overrides. |
| `odoo.physical-resources-cron` | Emits the `resources:` block for cron pods. Uses `odoo.cron.override_resources.cpu/memory` for overrides. |

Values by instance type:

| Profile | `WORKERS` | `LIMIT_MEMORY_HARD` | CPU limit | Mem limit |
|---------|-----------|--------------------|-----------|-----------| 
| `standard` | 1 | 2 GB | 1 | 2 Gi |
| `large` | 1 | 2.5 GB | 2 | 3 Gi |
| `xlarge` | 2 | 3 GB | 4 | 3.5 Gi |

---

#### `templates/_quotas_queuejob_helpers.tpl`

**Type**: Named template library  
**Role**: Defines resource sizing for the `queuejob` pod type.

| Template | Purpose |
|----------|---------|
| `odoo.internal-resources-queuejob` | Emits `WORKERS`, `LIMIT_MEMORY_SOFT`, `LIMIT_MEMORY_HARD`. Contains backward-compatibility logic: if the deprecated `odoo.queuejob.workers` field is set (`compatibility_workers`), it is used verbatim for `WORKERS`; otherwise per-size defaults apply (3 / 5 / 7). |
| `odoo.physical-resources-queuejob` | Emits the `resources:` block for queuejob pods. CPU/memory limits use `odoo.queuejob.override_resources`; requests use the separate `odoo.queuejob.override_request_resources` (allows decoupling request from limit). |

Values by instance type:

| Profile | `WORKERS` | `LIMIT_MEMORY_HARD` | CPU limit | Mem limit |
|---------|-----------|--------------------|-----------|-----------| 
| `standard` | 3 | 2 GB | 1 | 2 Gi |
| `large` | 5 | 2.5 GB | 2 | 3 Gi |
| `xlarge` | 7 | 3 GB | 4 | 3.5 Gi |

---

### `templates/` — Manifest files (rendered directly as Kubernetes resources)

---

#### `templates/deployment.yaml`

**Type**: Kubernetes manifest dispatcher  
**Role**: The top-level entry point for all Deployment resources. It does not define pod specs directly — instead it dispatches to the `odoo.deployment` named template and defines the queuejob Deployment inline.

Logic:
```
if odoo.mode == "hybrid":
    → include odoo.deployment with pod_type=thread
    → include odoo.deployment with pod_type=cron

elif odoo.mode == "workers":
    → include odoo.deployment with pod_type=worker

if odoo.queuejob.enabled:
    → inline Deployment for queuejob
```

The queuejob Deployment is defined inline (not via `_deployment_helpers.tpl`) because it has a distinct pod structure:
- Init container `wait-for-odoo`: uses `curl` to poll `/web/login` on the `thread` or `worker` Service in a loop until HTTP 200 is returned — ensures Odoo is fully started before the queue processor begins
- Container `odooqueue`: for new image flavour, explicitly passes `--load=<modules>,queue_job` on the command line; uses label `queuejob: "true"` (different selector from main pods, enabling the NetworkPolicy intra-namespace rule)
- Container `odoohealthz`: reads from `odoo-config-queuejob` and `odoohealthz-config`

Also unconditionally emits two additional Services at the bottom:
- `<fullname>-metrics`: ClusterIP on port 8080 targeting all pods via broad selector — used by the Prometheus `ServiceMonitor`
- `<fullname>`: Retro-compatibility ClusterIP on port 80, targeting `odoo-thread` (hybrid) or `odoo-worker` (workers) — allows existing references to the chart's root service name to continue working

---

#### `templates/config-odoo.yaml`

**Type**: ConfigMap manifest  
**Role**: Dispatches the `odoo.config` named template to emit one or two Odoo ConfigMaps depending on mode:
- `hybrid` → two ConfigMaps: `odoo-config[-<lab>]-thread` and `odoo-config[-<lab>]-cron`
- `workers` → one ConfigMap: `odoo-config[-<lab>]-worker`

Each ConfigMap carries the full set of Odoo env vars for that pod type. The sha256 of this file's rendered output is embedded as a pod annotation in every Deployment, triggering pod restarts on any change.

---

#### `templates/config-odoo-queue.yaml`

**Type**: ConfigMap manifest  
**Role**: Emits the `odoo-config[-<lab>]-queuejob` ConfigMap, but only when `odoo.queuejob.enabled: true`. Calls the same `odoo.config` named template with `pod_type=queuejob`, which appends `,queue_job` to `SERVER_WIDE_MODULES` and sets `DB_MAXCONN=5`, `MAX_CRON_THREADS=0`, and `ODOO_QUEUE_JOB_CHANNELS`. The sha256 of this file is embedded as `config-hash-queuejob` in the queuejob Deployment's pod annotations.

---

#### `templates/config-odoo-secret.yaml`

**Type**: Secret manifest (optional)  
**Role**: Emits an `odoo-secret[-<lab>]` Kubernetes `Secret` resource only when `odoo.secrets` is defined in values. The secret carries arbitrary key-value pairs base64-encoded. This secret is then referenced as an optional `secretRef` in all Odoo containers (`optional: true`, so pods start even if the secret is absent). Allows injecting arbitrary Odoo env overrides without defining them as plain ConfigMap entries. The sha256 of this file is embedded in pod annotations to trigger restarts on secret changes.

---

#### `templates/config-nginx.yaml`

**Type**: ConfigMap manifest  
**Role**: Emits the `nginx-config[-<lab>]` ConfigMap consumed by the nginx sidecar container in every pod. Contains:
- `NGX_ODOO_HOST`: upstream Odoo hostname (default `127.0.0.1`)
- `NGX_ODOO_LONGPOLLING_PORT`: longpolling port (default `8072`)
- `NGX_CACHE_SIZE`: optional nginx cache size (only emitted when set)
- `NGX_ODOO_PDFCONTENT`: optional PDF content setting (only emitted when set)

The nginx image reads these variables to configure itself at container start.

---

#### `templates/config-odoo-healthz.yaml`

**Type**: ConfigMap manifest  
**Role**: Emits the `odoohealthz-config[-<lab>]` ConfigMap consumed by the `odoohealthz` sidecar. Configures all health check behaviour:

| Key | Default | Purpose |
|-----|---------|---------|
| `ODOO_HEALTHZ_URL` | `http://localhost:8069` | Odoo URL to probe |
| `ODOO_TIMEOUT` | `30` | Request timeout in seconds |
| `CHECK_STUCK_JOB_ENABLED` | `False` | Enable stuck queue job detection |
| `GET_MAX_JOB_DURATION` | `3600` | Max acceptable job duration (seconds) |
| `CHECK_LONG_TRANSACTION_ENABLED` | `False` | Enable long DB transaction detection |
| `GET_MAX_TRANSACTION_DURATION` | `3600` | Max acceptable transaction duration |
| `CHECK_EXPIRED_DB` | `False` | Enable expired DB check |
| `ODOO_MEMORY_LIMIT` | `0` | Memory threshold for alerting (0 = disabled) |
| `ODOO_METRICS_URL` | `http://localhost:8069/metrics` | Odoo metrics endpoint |
| `ODOO_METRICS_TIMEOUT` | `2` | Metrics endpoint timeout |
| `LOGLEVEL` | `ERROR` | Log level for the sidecar itself |
| `COMPLETE_CHECK_OCCURENCE` | `0` | How often to run the full check suite |

---

#### `templates/config-odoo-preinit-manager.yaml`

**Type**: ConfigMap manifest  
**Role**: Emits the `preinit-manager-config[-<lab>]` ConfigMap consumed by the `preinit-manager` init container. Provides:
- Azure Key Vault credentials (`VAULT_NAME`, `CERT_NAME`, `TENANT_ID`, `CLIENT_ID`) — used to authenticate to Azure and retrieve the Celebrimbor certificate
- Odoo context (`CUSTOMER_NAME`, `ODOO_ENV`, optionally `LAB_NAME`) — used by the preinit manager to identify which instance it is coordinating
- `MIGRATION_FILE_PATH`: always `/tmp/migration.yml` — path where `marabunta-setup` copies the migration spec
- `CELEBRIMBOR_SVC`: URL of the Celebrimbor service (default `http://celebrimbor.celebrimbor.svc.cluster.local`) — the preinit manager contacts this to verify migration eligibility and trigger backups
- `ONERING_SVC`: optional URL of the Onering orchestration service

---

#### `templates/ingressRoutes.yaml`

**Type**: Traefik CRD manifest  
**Role**: Generates Traefik `IngressRoute` resources for all configured routes. This is the primary ingress configuration file.

Iteration structure:
```
for route in ingressRoutes.routes:
  for hostGroup in route.hostList:
    → emit one IngressRoute named odoo-ingress-<sha1(hosts)>
      for path in route.paths:
        for entry in path.list:
          → emit one route rule (Path/PathPrefix/PathRegexp match)
            → attach middleware chain
```

Key behaviours:
- Host match expression is assembled as `(Host(\`a\`) || Host(\`b\`))` from the `list` array
- The `IngressRoute` name uses `sha1sum` of the host expression — stable across upgrades, collision-free
- Path type `specific` → `Path()` with priority 65535; `prefix` → `PathPrefix()` with priority 0; anything else → `PathRegexp()` with priority 65535
- Service target: `<fullname>-<path.component | defaultComponent>` port 80 — allows routing specific paths to a different pod type (e.g. `/longpolling` to a dedicated component)
- Middleware chain: always starts with `mw-hs-security`, then conditionally appends each middleware type based on `useDefault` flag (use the default variant) or presence of `override` (use a path-specific variant with a hash-based name)
- TLS: `store: default` when `certificate.useDefault: true`; otherwise `secretName: sct-<sha1(hosts)>` which is the secret created by `certificates.yaml`

---

#### `templates/middleware.yaml`

**Type**: Traefik CRD manifest  
**Role**: Generates per-route Traefik `Middleware` resources and the always-present `mw-hs-security` middleware.

Iterates the same route/hostGroup/path/list structure as `ingressRoutes.yaml`. For each path, for each middleware type (`IPAllowList`, `waf`, `robotNoIndex`, `rateLimits`, `redirectScheme`, `redirectRegex`, `retry`), emits a `Middleware` resource only when `useDefault: false` AND an `override` value is provided.

Resource names use `sha1sum` of a string combining the middleware type, host expression, and path list — guaranteeing uniqueness per (route, path) combination without collisions.

Always emits (unconditionally, at the end of the file):

```yaml
mw-hs-security[-<lab>]:
  headers:
    stsSeconds: 31536000
    stsIncludeSubdomains: true
    stsPreload: true
```

This middleware is referenced first in every IngressRoute's middleware chain.

---

#### `templates/defaultMiddleware.yaml`

**Type**: Traefik CRD manifest  
**Role**: Generates the "default" Traefik `Middleware` resources — shared middlewares that any route can reference with `useDefault: true` without needing to repeat the full configuration. Triggered by the presence of entries under `ingressRoutes.defaultMiddlewares`.

For each middleware type defined under `defaultMiddlewares`, emits the corresponding `mw-*-default[-<lab>]` resource:
- `mw-ip-default`: `ipAllowList` with `sourceRange` list
- `mw-wf-default`: `forwardAuth` with `address` (and optional `trustForwardHeader`)
- `mw-rn-default`: `headers` with `X-Robots-Tag: noindex,nofollow,noarchive,nosnippet,noimageindex`
- `mw-rl-default`: `rateLimit` with `average`, optional `burst` and `period`
- `mw-rs-default`: `redirectScheme` with `scheme`, optional `permanent` and `port`
- `mw-rr-default-<hash>`: one `redirectRegex` per entry in the list (hash of regex + replacement)
- `mw-retry-default`: `retry` with `attempts` and `initialInterval`

---

#### `templates/certificates.yaml`

**Type**: cert-manager CRD manifest  
**Role**: Generates cert-manager `Certificate` resources for all host groups where `certificate.useDefault: false`. When `useDefault: true`, TLS is handled by the Traefik default TLS store (no Certificate resource needed). When `false`, the chart provisions a dedicated TLS certificate via cert-manager.

For each such host group:
- Creates a `Certificate` named `crt-<sha1(hosts)>` (stable, deterministic name)
- Sets `secretName: sct-<sha1(hosts)>` — this is the same name referenced by the `tls.secretName` in `ingressRoutes.yaml`, completing the TLS chain
- Lists all hostnames in `dnsNames`
- References a `ClusterIssuer` by name from `certificate.issuerRef` (e.g. `letsencrypt-prod`)

---

#### `templates/networkPolicies.yaml`

**Type**: Kubernetes NetworkPolicy manifest  
**Role**: Emits a `NetworkPolicy` resource when `networkPolicies.enabled: true` (default). Restricts pod ingress to a well-known set of sources, implementing a default-deny posture for the Odoo namespace.

Allowed ingress sources (always):
- Traefik pods in namespace `traefik` (matched by both namespace label and pod label `app.kubernetes.io/name: traefik`)
- Prometheus pods in namespace `kube-prometheus-stack` (matched by both namespace label and pod label `app.kubernetes.io/name: prometheus`)

Conditional (`enableSharedPrintinServices: true`):
- Pods with `app.kubernetes.io/name: kwkhtmltopdf` in namespaces `bs-kwkhtmltopdf01250`, `bs-kwkhtmltopdf01261`, `bs-kwkhtmltopdflog`
- Intra-namespace pods with label `queuejob: "true"` (allows the queuejob Deployment to call back into the main Odoo pod)

Legacy (`explicitNamespacesSelector`): allows arbitrary additional namespace selectors (deprecated, kept for backward compatibility).

The `podSelector: {}` at the end selects all pods in the namespace, applying this policy to every pod.

---

#### `templates/servicemonitor.yaml`

**Type**: Prometheus Operator CRD manifest  
**Role**: Emits a `ServiceMonitor` resource when `serviceMonitor.enabled: true`. This is the Prometheus Operator custom resource that tells Prometheus to scrape this chart's metrics.

Configuration:
- `namespaceSelector`: restricts scraping to the release namespace
- `selector`: matches pods via `odoo.selectorLabels` (`app.kubernetes.io/name` + `app.kubernetes.io/instance`)
- `endpoints`: scrapes port `metrics` (8080) at path `/metrics` with interval from `odoo.metrics.scrapeInterval` (default `15s`)

The `<fullname>-metrics` Service defined in `deployment.yaml` is the scrape target — it uses a broad selector (only `selectorLabels`, no component label) so all pod types (worker, thread, cron, queuejob) are scraped through a single Service.

---

#### `templates/podDisruptionBudget.yaml`

**Type**: Kubernetes PodDisruptionBudget manifest  
**Role**: Emits a `PodDisruptionBudget` named `odoo-pdb[-<lab>]` only when `podDisruptionBudget` is defined in values. Protects against accidental full-cluster disruption during node maintenance or rolling upgrades.

Supports either:
- `podDisruptionBudget.minAvailable`: minimum number of pods that must remain available
- `podDisruptionBudget.maxUnavailable`: maximum number of pods that can be unavailable simultaneously

The selector matches all pods in the release by `selectorLabels` and `release` label, covering all pod types (worker/thread/cron) simultaneously.

---

#### `templates/rbac.yaml`

**Type**: Kubernetes RBAC manifest  
**Role**: Emits `RoleBinding` resources for access control. Two independent mechanisms:

1. **Custom RoleBindings** (`roleBindings` map): iterates the map and emits one `RoleBinding` per entry. The key becomes the `metadata.name`, the value is the full `RoleBinding` spec in YAML. Allows arbitrary role assignments to be declared entirely in values.

2. **BS Team power user shortcut** (`bsTeamPowerUserGroupId`): when set, emits a `bs-team-power-user[-<lab>]` `RoleBinding` that binds the given Azure AD group ID to the `pod-exec` `ClusterRole`. This grants members of the BS support team the ability to run `kubectl exec` into Odoo pods for production debugging, without needing full cluster admin access.
