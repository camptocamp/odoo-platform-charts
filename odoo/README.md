# Odoo Helm Chart

A Helm chart to deploy Odoo on the Camptocamp platform (version `5.3.5`).

## Overview

This chart deploys a production-grade Odoo instance on Kubernetes with the following components in each pod:

- **Odoo** — the main application server
- **Nginx** — reverse proxy / static asset serving
- **odoohealthz** — sidecar exposing `/liveness`, `/readiness`, and `/metrics` endpoints
- **preinit-manager** (init container) — coordinates database migrations before startup
- **marabunta** (init container) — runs database migrations

## Prerequisites

- Kubernetes 1.21+
- Helm 3+
- [Traefik](https://traefik.io/) (for `IngressRoute` resources)
- [cert-manager](https://cert-manager.io/) (for `Certificate` resources, if not using the default TLS store)
- [Prometheus Operator](https://prometheus-operator.dev/) (if `serviceMonitor.enabled: true`)
- The following Kubernetes secrets must exist in the namespace before deployment:
  - `odoo-database` — PostgreSQL credentials
  - `odoo-storage` — Azure Blob Storage credentials
  - `github-packages` — image pull secret (default)
  - `odoo-redis` — Redis URL (if `odoo.redis.enabled: true`)

## Deployment Modes

The chart supports two deployment modes controlled by `odoo.mode`:

| Mode | Description |
|------|-------------|
| `workers` (default) | Single deployment with Odoo multi-process workers (thread + cron in one pod type) |
| `hybrid` | Two separate deployments: `thread` (HTTP handling) and `cron` (scheduled jobs) |

When `odoo.queuejob.enabled: true`, a third dedicated `queuejob` deployment is created regardless of mode.

## Installing the Chart

```bash
helm install my-odoo ./odoo -f my-values.yaml
```

## Kubernetes Resources Created

| Resource | Kind | Notes |
|----------|------|-------|
| `<name>-worker` or `<name>-thread` / `<name>-cron` | `Deployment` | Main Odoo pod(s), depending on mode |
| `<name>-queuejob` | `Deployment` | Created only when `odoo.queuejob.enabled: true` |
| `<name>-worker` / `<name>-thread` / `<name>-cron` | `Service` | Per-component ClusterIP services |
| `<name>-metrics` | `Service` | Exposes port 8080 for Prometheus scraping |
| `<name>` | `Service` | Compatibility service pointing to the main component |
| `odoo-config-<type>` | `ConfigMap` | Odoo environment configuration per pod type |
| `nginx-config` | `ConfigMap` | Nginx configuration |
| `odoohealthz-config` | `ConfigMap` | Health check sidecar configuration |
| `preinit-manager-config` | `ConfigMap` | Pre-init manager (migration coordinator) configuration |
| `odoo-config-queuejob` | `ConfigMap` | Queue job worker configuration |
| `odoo-secret` | — | Optional secret reference (must exist externally) |
| `odoo-pdb` | `PodDisruptionBudget` | Created only when `podDisruptionBudget` is set |
| `<name>` | `NetworkPolicy` | Created when `networkPolicies.enabled: true` |
| `<name>` | `ServiceMonitor` | Created when `serviceMonitor.enabled: true` |
| `odoo-ingress-<hash>` | `IngressRoute` (Traefik) | Created when `ingressRoutes.routes` is configured |
| `mw-*` | `Middleware` (Traefik) | Created per route middleware configuration |
| `crt-<hash>` | `Certificate` (cert-manager) | Created for routes with custom issuer |
| `RoleBinding` | `RoleBinding` | Created from `roleBindings` values or `bsTeamPowerUserGroupId` |

## Values Reference

### Global

| Parameter | Description | Default |
|-----------|-------------|---------|
| `replicaCount` | Number of replicas for the main deployment | `1` |
| `extraLabels` | Extra labels to add to all resources | `{}` |
| `additionalLabels` | Additional labels on pod templates | `{}` |
| `additionalAnnotations` | Additional annotations on pod templates | `{}` |
| `serviceAccountName` | Service account to use | `"default"` |
| `nodeSelector` | Node selector for all pods | `{}` |
| `tolerations` | Tolerations for all pods | `[]` |
| `affinity` | Affinity rules for all pods | `{}` |
| `securityContext` | Security context per component (`odoo`, `queuejob`) | `{}` |
| `rollingupdatechart` | Force `RollingUpdate` strategy (otherwise `Recreate`) | `false` |
| `separateOdooComponents` | Pin components to dedicated nodes via node labels | `false` |

### Pod Spread

| Parameter | Description | Default |
|-----------|-------------|---------|
| `spreadOdooPodsOverNodes.enabled` | Enable `topologySpreadConstraints` | `true` |
| `spreadOdooPodsOverNodes.maxSkew` | Max skew for spread | `1` |
| `spreadOdooPodsOverNodes.topologyKey` | Topology key | `kubernetes.io/hostname` |
| `spreadOdooPodsOverNodes.whenUnsatisfiable` | Behavior when unsatisfiable | `ScheduleAnyway` |

### Images

| Parameter | Description | Default |
|-----------|-------------|---------|
| `image.pullPolicy` | Image pull policy | `IfNotPresent` |
| `image.odoo.repository` | Odoo image repository | `ghcr.io/camptocamp/customer_odoo` |
| `image.odoo.tag` | Odoo image tag | `xx.0.1.0.0` |
| `image.odoo.is_old_image_flavour` | Use legacy entrypoint format | `true` |
| `image.nginx.repository` | Nginx image repository | `camptocamp.azurecr.io/odoo/odoo-nginx` |
| `image.nginx.tag` | Nginx image tag | `xx.0-1.6.0` |
| `image.odoohealthz.repository` | Health check sidecar repository | `camptocamp.azurecr.io/odoo/odoo-k8s-healthz` |
| `image.odoohealthz.tag` | Health check sidecar tag | `app-1.7.0` |
| `image.preinit_manager.repository` | Pre-init manager repository | `camptocamp.azurecr.io/odoo/odoo-preinit-manager` |
| `image.preinit_manager.tag` | Pre-init manager tag | `1.2.2` |
| `image.curl.repository` | Curl image (used in init containers) | `camptocamp.azurecr.io/odoo/curl` |
| `image.curl.tag` | Curl image tag | `7.81.0` |
| `imagePullSecrets` | Image pull secrets | `[{name: github-packages}]` |

### Odoo Application

| Parameter | Description | Default |
|-----------|-------------|---------|
| `odoo.odoo_version` | Odoo version (numeric) | `18.0` |
| `odoo.customerName` | Customer name (used in resource naming) | `customer` |
| `odoo.env` | Environment (`integration`, `prod`, `labs`, …) | `integration` |
| `odoo.instance_type` | Instance sizing profile (`standard`, `large`, `xlarge`) | `standard` |
| `odoo.mode` | Deployment mode: `workers` or `hybrid` | `workers` |
| `odoo.base_url` | Odoo base URL | `""` |
| `odoo.report_url` | Odoo report URL | `""` |
| `odoo.log_handler` | Log handler configuration | `:INFO,azure:ERROR` |
| `odoo.log_level` | Log level | `info` |
| `odoo.unaccent` | Enable unaccent extension | `"False"` |
| `odoo.demo` | Enable demo data | `"False"` |
| `odoo.server_wide_modules` | Server-wide modules (comma-separated) | depends on odoo_version |
| `odoo.server_env_config` | server_env module configuration | `""` |
| `odoo.kwkhtmltopdf_server_url` | KWKHTMLtoPDF server URL | `http://kwkhtmltopdf.bs-kwkhtmltopdf01250:8080` |
| `odoo.override_limits` | Override Odoo internal memory/worker limits | `{}` |
| `odoo.override_resources` | Override pod CPU/memory resource requests/limits | `{}` |

### Odoo Limits

| Parameter | Description | Default |
|-----------|-------------|---------|
| `odoo.limits.time_cpu` | CPU time limit (seconds) | `86400` |
| `odoo.limits.time_real` | Real time limit (seconds) | `86400` |
| `odoo.limits.time_real_cron` | Real time limit for cron | `600` |
| `odoo.limits.request` | Max request size | `8192` |

### Database

| Parameter | Description | Default |
|-----------|-------------|---------|
| `odoo.db.secret.name` | Secret name containing DB credentials | `odoo-database` |
| `odoo.db.secret.host` | Key in secret for DB host | `master` |
| `odoo.db.secret.user` | Key in secret for DB user | `username` |
| `odoo.db.secret.password` | Key in secret for DB password | `password` |
| `odoo.db.secret.database` | Key in secret for DB name | `database` |
| `odoo.db.port` | PostgreSQL port | `"5432"` |

### Azure Storage

| Parameter | Description | Default |
|-----------|-------------|---------|
| `odoo.storage.account_url` | Azure Blob Storage account URL | `"dummy"` |
| `odoo.storage.use_aad` | Use AAD for Azure auth | `'1'` |
| `odoo.storage.secret.name` | Secret name for storage | `odoo-storage` |
| `odoo.storage.secret.container` | Key in secret for container name | `container_name` |

### Redis (optional)

| Parameter | Description | Default |
|-----------|-------------|---------|
| `odoo.redis.enabled` | Enable Redis session storage | `false` |
| `odoo.redis.secret.name` | Secret name for Redis | `odoo-redis` |
| `odoo.redis.secret.url` | Key in secret for Redis URL | `url` |

### Marabunta (Migrations)

| Parameter | Description | Default |
|-----------|-------------|---------|
| `odoo.marabunta.enabled` | Enable migration init containers | `"True"` |
| `odoo.marabunta.mode` | Migration mode | `Full` |
| `odoo.marabunta.allow_series` | Allow migration series | `"False"` |
| `odoo.marabunta.force_backup` | Force backup before migration | `false` |

### Cron Component

| Parameter | Description | Default |
|-----------|-------------|---------|
| `odoo.cron.defaultReplicaCount` | Replica count for cron deployment | `1` |
| `odoo.cron.db.max_conn` | Max DB connections for cron | `20` |
| `odoo.cron.limits.max_cron` | Max cron threads | `2` |
| `odoo.cron.override_limits` | Override cron internal limits | `{}` |
| `odoo.cron.override_resources` | Override cron pod resources | `{}` |

### Queue Job Component

| Parameter | Description | Default |
|-----------|-------------|---------|
| `odoo.queuejob.enabled` | Enable the queue job deployment | `false` |
| `odoo.queuejob.defaultReplicaCount` | Replica count | `1` |
| `odoo.queuejob.channels` | Queue job channels | `"root:2"` |
| `odoo.queuejob.db.max_conn` | Max DB connections | `5` |
| `odoo.queuejob.override_limits` | Override internal limits | `{}` |
| `odoo.queuejob.override_resources` | Override pod resources | `{}` |

### Instance Sizing Profiles

Resource requests and internal Odoo limits are automatically set based on `odoo.instance_type`:

| Profile | Workers | CPU limit | Memory limit |
|---------|---------|-----------|--------------|
| `standard` | 7 | 1 | 2.2Gi |
| `large` | 14 | 2 | 3Gi |
| `xlarge` | 14 | 4 | 3.5Gi |

Use `odoo.override_limits` and `odoo.override_resources` to fine-tune individual values.

### Health Checks

| Parameter | Description | Default |
|-----------|-------------|---------|
| `odoo.livenessProbe` | Liveness probe config | `GET /liveness :8080, every 60s` |
| `odoo.readinessProbe` | Readiness probe config | `GET /readiness :8080, every 2s` |
| `odoo.startupProbe` | Startup probe config | `GET /liveness :8080, 30 retries` |
| `odoo.queuejob.livenessProbe` | Queue job liveness probe | `GET /queue_liveness :8080` |
| `odoo.queuejob.startupProbe` | Queue job startup probe | `GET /queue_liveness :8080` |

### Nginx

| Parameter | Description | Default |
|-----------|-------------|---------|
| `nginx.odooHost` | Odoo upstream host | `localhost` |
| `nginx.odooLongpollingPort` | Longpolling port | `"8072"` |

### Metrics

| Parameter | Description | Default |
|-----------|-------------|---------|
| `serviceMonitor.enabled` | Create a Prometheus `ServiceMonitor` | `false` |
| `odoo.metrics.scrapeInterval` | Prometheus scrape interval | `15s` |

### odoohealthz Sidecar

All keys are optional. See the values file for the full list.

| Parameter | Description |
|-----------|-------------|
| `odoohealthz.odoo_url` | Odoo URL to probe |
| `odoohealthz.odoo_timeout` | Request timeout |
| `odoohealthz.check_stuck_job` | Check for stuck queue jobs |
| `odoohealthz.max_job_duration` | Max acceptable job duration |
| `odoohealthz.check_long_transaction` | Check for long-running DB transactions |
| `odoohealthz.odoo_memory_limit` | Memory limit threshold for alerting |

### Network Policies

| Parameter | Description | Default |
|-----------|-------------|---------|
| `networkPolicies.enabled` | Create a `NetworkPolicy` | `true` |
| `networkPolicies.enableSharedPrintinServices` | Allow ingress from shared kwkhtmltopdf namespaces | `true` |
| `networkPolicies.extraFrom` | Additional ingress rules | `{}` |
| `networkPolicies.explicitNamespacesSelector` | (Deprecated) Additional namespace selectors | `{}` |

The policy allows ingress from:
- Traefik (namespace `traefik`)
- Prometheus (namespace `kube-prometheus-stack`)
- Shared kwkhtmltopdf services (when enabled)
- Queue job pods (same namespace)

### Ingress (Traefik IngressRoutes)

Routes are configured under `ingressRoutes.routes`. Each route supports:

- Multiple host lists with per-host TLS configuration
- Path rules with types: `prefix`, `specific`, `regex`
- Per-path or default middlewares: `IPAllowList`, `waf`, `robotNoIndex`, `rateLimits`, `redirectScheme`, `redirectRegex`, `retry`, `externalMiddlewares`

A default HSTS security middleware (`mw-hs-security`) is always created.

Example:

```yaml
ingressRoutes:
  defaultMiddlewares:
    IPAllowList:
      - "10.0.0.0/8"
    rateLimits:
      average: 200
      burst: 5
      period: "1m"
    redirectScheme:
      scheme: https
      permanent: true
      port: "443"
  routes:
    - hostList:
        - list:
            - "odoo.example.com"
          certificate:
            useDefault: false
            issuerRef: "letsencrypt-prod"
      entryPoints:
        - websecure
      paths:
        - list:
            - path: "/"
              type: prefix
          middlewares:
            IPAllowList:
              useDefault: true
            rateLimits:
              useDefault: true
```

### RBAC

| Parameter | Description | Default |
|-----------|-------------|---------|
| `roleBindings` | Map of `RoleBinding` objects to create | `{}` |
| `bsTeamPowerUserGroupId` | Azure AD group ID granted `pod-exec` ClusterRole | `""` |

### Pod Disruption Budget

```yaml
podDisruptionBudget:
  minAvailable: 1
  # or:
  # maxUnavailable: 1
```

### Pre-init Manager

| Parameter | Description | Default |
|-----------|-------------|---------|
| `preinit_manager.celebrimbor_cert.name` | Certificate name in Azure Key Vault | `celebrimbor` |
| `preinit_manager.celebrimbor_cert.vault_name` | Azure Key Vault name | `""` |
| `preinit_manager.azure.tenant_id` | Azure tenant ID | `""` |
| `preinit_manager.azure.client_id` | Azure client ID | `""` |
| `preinit_manager.celebrimbor_svc` | Celebrimbor service URL | `http://celebrimbor.celebrimbor.svc.cluster.local` |
| `preinit_manager.onering_svc` | Onering service URL | `""` |

## Labs Environment

When `odoo.env: labs`, set `odoo.lab_name` to differentiate lab instances. Resource names will include the lab name as a suffix, allowing multiple lab instances to coexist in the same namespace.

## Rolling Updates

By default the deployment strategy is `Recreate`. To use `RollingUpdate`:

- Set `rollingupdatechart: true`, **or**
- Use an image tag ending in `-roll` (e.g. `18.0.1.0.0-roll`)

## Extra Volumes

Custom volumes can be mounted into the Odoo and queue job containers:

```yaml
volumes:
  odoo:
    - name: my-volume
      configMap:
        name: my-config
  queuejob:
    - name: my-qj-volume
      secret:
        secretName: my-secret

volumeMounts:
  odoo:
    - name: my-volume
      mountPath: /etc/my-config
  queuejob:
    - name: my-qj-volume
      mountPath: /etc/my-secret
```
