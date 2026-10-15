# Odoo

Deploys Odoo for the Camptocamp platform. The standard workload combines the Odoo application, Nginx, and the `odoohealthz` sidecar; migration-related init containers and a queue-job deployment are enabled according to values.

## Deployment modes

| `odoo.mode` | Workloads |
|---|---|
| `workers` (default) | Odoo worker deployment |
| `hybrid` | Separate thread and cron deployments |

`odoo.queuejob.enabled` defaults to `true` and adds a dedicated queue-job deployment.

## Prerequisites

Create the required Secrets in the target namespace before deployment:

- Database Secret, default `odoo-database`, with `master`, `database`, `username`, and `password` keys.
- Storage Secret, default `odoo-storage`, with `container_name` key.
- Redis Secret, default `odoo-redis`, with `url` key when Redis is enabled.
- Registry pull Secret, default `github-packages`, when the selected images require one.

The chart also requires reachable PostgreSQL and Azure Blob Storage. Traefik, cert-manager, and Prometheus Operator are needed only for their corresponding optional resources.

## Install

```bash
kubectl create namespace odoo
kubectl -n odoo create secret generic odoo-database \
  --from-literal=master='postgres.example.internal' \
  --from-literal=database='odoo' \
  --from-literal=username='odoo' \
  --from-literal=password='REPLACE_ME'
kubectl -n odoo create secret generic odoo-storage \
  --from-literal=container_name='odoo-data'

helm upgrade --install my-odoo ./odoo \
  --namespace odoo \
  --set odoo.customerName=mycustomer \
  --set odoo.env=integration \
  --values values.yaml
```

## Resources created

Always-created resources include Odoo Deployments, component Services, ConfigMaps, NetworkPolicies, and Traefik HSTS middleware. Optional values can create a chart-managed Secret, queue-job workload, ServiceMonitors, core metrics Service, PodDisruptionBudget, RoleBindings, IngressRoutes, Middleware, and Certificates.

## Main values

| Value group | Purpose |
|---|---|
| `replicaCount`, `odoo.mode`, `odoo.queuejob.*`, `odoo.cron.*` | Workload topology and scaling |
| `image.*`, `imagePullSecrets` | Images and registry credentials |
| `odoo.*` | Odoo version, customer/environment settings, runtime, migrations, database, storage, Redis, and extra environment variables |
| `resources`, `securityContext`, scheduling values | Compute, security, availability, and Pod placement |
| `networkPolicies.*`, `ingressRoutes.*`, `nginx.*` | Network exposure and ingress behavior |
| `odoohealthz.*`, `serviceMonitor.*`, `serviceMonitorOdooMetrics.*` | Health and observability |
| `odoo.secrets`, `volumes`, `volumeMounts` | Additional sensitive configuration and extensions |

## Upgrade and operations

Render changes before applying them, especially when changing migrations, ingress, networking, resource settings, or Odoo mode.

```bash
helm template my-odoo ./odoo --namespace odoo --values values.yaml
helm -n odoo status my-odoo
helm -n odoo history my-odoo
```

Do not store production Secret values in a committed values file. Use a secret-management workflow or pre-created Kubernetes Secrets.
