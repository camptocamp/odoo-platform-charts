# autossh

Deploys an autossh-based SSH tunnel and exposes its local forwarding port through a Kubernetes Service.

## Prerequisites

- Helm 3 and a Kubernetes cluster.
- Network access from the Pod to the SSH endpoint and target service.
- An SSH private key for the tunnel account.

## Resources created

- Deployment
- ClusterIP Service by default
- ConfigMap containing tunnel settings
- Secret named `autossh-secret` when `autossh.secrets` is configured

## Required configuration

The Deployment always references a Secret named `autossh-secret`. Set `autossh.secrets` to let the chart create it, or create that Secret separately in the release namespace.

```yaml
autossh:
  secrets:
    SSH_KEY_FILE: |
      -----BEGIN OPENSSH PRIVATE KEY-----
      ...
      -----END OPENSSH PRIVATE KEY-----
  ssh_remote_host: bastion.example.net
  ssh_remote_user: tunnel-user
  ssh_target_host: internal-service.default.svc.cluster.local
  ssh_target_port: "631"
  ssh_tunnel_port: "631"
```

## Install

```bash
helm upgrade --install autossh ./autossh \
  --namespace autossh \
  --create-namespace \
  --values values.yaml
```

## Main values

| Value group | Purpose |
|---|---|
| `autossh.ssh_*` | SSH endpoint, forwarding mode, local port, and target endpoint |
| `autossh.server_alive_count_max` | SSH keepalive retry limit |
| `autossh.secrets` | Values rendered into the `autossh-secret` Secret |
| `image.*`, `replicaCount`, `resources` | Workload image, scaling, and resources |
| `service.*` | Service name and type |
| `nodeSelector`, `tolerations`, `affinity` | Scheduling |

## Notes

- The Service port follows `autossh.ssh_tunnel_port`; `service.port` is not consumed by the current template.
- The chart does not create Ingress, RBAC, persistence, autoscaling, or active probes.
- Protect SSH keys with an external secret-management process when possible.
