# kwkhtmltopdf

Deploys an HTML-to-PDF rendering service using the `acsone/kwkhtmltopdf` image.

## Resources created

- Deployment with TCP readiness and liveness probes on port 8080
- ClusterIP Service exposing port 8080
- ConfigMap named `kwkhtmltopdf-config`

The Pod mounts an `emptyDir` volume at `/tmp` by default.

## Install

```bash
helm upgrade --install kwkhtmltopdf ./kwkhtmltopdf \
  --namespace document-tools \
  --create-namespace
```

To prevent the application from cleaning storage:

```bash
helm upgrade --install kwkhtmltopdf ./kwkhtmltopdf \
  --namespace document-tools \
  --create-namespace \
  --set no_storage_cleaning=true
```

## Main values

| Value | Default | Purpose |
|---|---:|---|
| `replicaCount` | `1` | Deployment replicas |
| `image.kwkhtmltopdf.repository` | `acsone/kwkhtmltopdf` | Container image |
| `image.kwkhtmltopdf.tag` | `0.12.1.3-latest` | Container image tag |
| `services.kwkhtmltopdf.targetPort` | `8080` | Service port |
| `resources.kwkhtmltopdf` | — | Requests and limits |
| `no_storage_cleaning` | unset | Sets `NO_STORAGE_CLEANING` |

## Notes

- No Secret, Ingress, RBAC, persistence, or chart dependency is created.
- The Service defaults to `ClusterIP` because the template does not set a type.
- `kwkhtmltopdf-config` has a fixed name; avoid multiple releases in the same namespace.
