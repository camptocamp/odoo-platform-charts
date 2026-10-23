# Odyssey

Deploys Odyssey, a PostgreSQL connection pooler/proxy. It exposes PostgreSQL traffic on port 5432 and metrics on port 8080.

## Prerequisites

- Helm 3 and Kubernetes.
- A reachable PostgreSQL backend.
- Prometheus Operator `ServiceMonitor` CRD: the chart always creates a ServiceMonitor.
- cert-manager and a valid issuer when `certificate.enabled=true` (enabled by default).
- An image pull Secret when the default `github-packages` Secret is required by the selected image.

## Resources created

- Deployment
- Configuration ConfigMap containing `odyssey.conf`
- Primary PostgreSQL Service when `service.enabled=true`
- Metrics Service
- cert-manager Certificate when enabled
- ServiceMonitor

## Required configuration

Provide an Odyssey listener, at least one storage definition, and database routing entries.

```yaml
certificate:
  enabled: false
livenessProbe: null
imagePullSecrets: []
settings:
  listen:
    host: "0.0.0.0"
    port: 5432
    tls: disable
  storages:
    postgres:
      type: remote
      host: postgres.example.internal
      port: 5432
      tls: require
  databases_list:
    odoo:
      database: odoo
      username: odoo
      password: "<managed-secret-value>"
      storage: postgres
      options:
        pool: transaction
        pool_size: 20
```

## Install

```bash
helm upgrade --install odyssey ./odyssey \
  --namespace odoo \
  --create-namespace \
  --values values-odyssey.yaml
```

## Main values

| Value group | Purpose |
|---|---|
| `settings.globals`, `settings.listen` | Global Odyssey behavior and listener |
| `settings.storages`, `settings.databases_list` | PostgreSQL backends and routing |
| `replicaCount`, `resources`, scheduling values | Workload sizing and placement |
| `service.*`, `internalPort`, `servicePort` | PostgreSQL Service exposure |
| `certificate.*` | cert-manager Certificate generation |
| `metrics.scrapeInterval` | Metrics ServiceMonitor interval |
| `volumes`, `volumeMounts` | Mount externally managed files or Secrets |

## Security notes

Database passwords in `settings.databases_list` are rendered into the configuration ConfigMap. The chart does not provide native Secret references for these values. Use a protected values delivery mechanism or mount externally managed configuration through `volumes` and `volumeMounts`.

A generated Certificate is not automatically mounted or configured in Odyssey. Configure the required TLS files and Odyssey settings explicitly when enabling TLS.
