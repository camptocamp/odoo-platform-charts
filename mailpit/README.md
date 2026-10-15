# Mailpit

Deploys Mailpit, an SMTP testing service with a web UI and API.

## Prerequisites

- Helm 3 and Kubernetes.
- Traefik `IngressRoute` CRD and cert-manager `Certificate` CRD: this chart creates both by default.
- A `letsencrypt-prod` ClusterIssuer.
- Registry access for the selected Mailpit image.
- A NetworkPolicy-capable CNI when policy enforcement is required.

## Resources created

- Deployment
- HTTP Service (port 80 to container port 8025) and SMTP Service (port 25 to container port 1025)
- NetworkPolicy
- cert-manager Certificate and Traefik IngressRoute
- Optional IP allow-list Middleware, PVC, authentication ConfigMap, and SMTP relay Secret

## Install

The chart defaults to zero replicas, so set a positive replica count and a real host name.

```bash
helm upgrade --install mailpit ./mailpit \
  --namespace mailpit \
  --create-namespace \
  --set replicaCount=1 \
  --set ingressRoutes.host=mailpit.example.com \
  --set persistence.enabled=true
```

## Main values

| Value group | Purpose |
|---|---|
| `replicaCount`, `resources`, `args`, `extraEnvVars` | Workload behavior |
| `image.*`, `global.image*` | Image selection and registry access |
| `persistence.*` | Mailpit SQLite database persistence |
| `service.http.*`, `service.smtp.*` | Service types and NodePorts |
| `ingressRoutes.*` | HTTPS host and optional IP allow list |
| `mailpit.ui.*`, `mailpit.smtp.*` | Basic authentication and TLS Secrets |
| `mailpit.relay.*` | SMTP relay configuration |

## Security notes

- UI and SMTP TLS Secrets must contain `tls.crt` and `tls.key`.
- Treat relay configuration as sensitive; the chart renders it into a Kubernetes Secret.
- Basic-auth content is rendered into a ConfigMap, so do not use it for credentials requiring strong at-rest protection.

## Operational notes

- The chart is opinionated about Traefik, cert-manager, the `letsencrypt-prod` issuer, and its NetworkPolicy source namespaces/labels.
- The SMTP-auth-only path has a current template limitation: enabling SMTP authentication without UI authentication does not mount the generated auth file. Enable UI auth too or validate the rendered manifest before relying on SMTP-only auth.
