# Celebrimbor

Deploys Celebrimbor with an Nginx sidecar, Azure Workload Identity, Azure Key Vault-backed ExternalSecrets, and optional Traefik ingress.

## Prerequisites

- Helm 3 and Kubernetes.
- External Secrets Operator and its `SecretStore` / `ExternalSecret` CRDs.
- Azure Workload Identity configured for the selected ServiceAccount.
- Azure Key Vault access for the configured managed identity.
- Redis and Azure storage configuration.
- For ingress: Traefik CRDs, cert-manager, and a `letsencrypt-prod` ClusterIssuer.

## Resources created

- ServiceAccount, Deployment, Service, and application/Nginx ConfigMaps
- Azure Key Vault `SecretStore`
- ExternalSecrets for application, GPG, Redis, and storage settings
- Optional ExternalSecrets and CronJob for key backup
- Optional Traefik `IngressRoute`, `Middleware`, and cert-manager `Certificate`

## Required values and Key Vault data

```yaml
keyvaultName: my-key-vault
serviceAccountName: celebrimbor
identity:
  clientID: "<managed-identity-client-id>"
  tenantID: "<azure-tenant-id>"
```

The Key Vault must provide the application credentials and storage settings used by the generated ExternalSecrets, including `CLIENT-ID`, `CLIENT-SECRET`, `TENANT-ID`, `SESSION-REDIS-URL`, and the required Azure storage keys.

## Install

```bash
helm upgrade --install celebrimbor ./celebrimbor \
  --namespace celebrimbor \
  --create-namespace \
  --values values.yaml
```

## Main values

| Value group | Purpose |
|---|---|
| `identity.*`, `keyvaultName`, `serviceAccountName` | Azure Workload Identity and Key Vault access |
| `image.*`, `replicaCount`, `resources.*` | Images, scaling, and per-container resources |
| `celebrimbor.*` | Application runtime, internal cron, additional secrets, and key backup |
| `ingress.*` | Traefik route, host names, and IP allow list |
| `volumes`, `volumeMounts` | Additional Pod storage |
| `nodeSelector`, `tolerations`, `affinity` | Scheduling |

## Operational notes

- ExternalSecrets materialize sensitive data from Key Vault; do not add those values to committed files.
- Ingress is disabled by default.
- `service.port` is used by the Traefik route; the Service itself exposes Nginx on port 80.
