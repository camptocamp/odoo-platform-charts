# py3o

Deploys the Py3o document-generation service.

## Resources created

- Deployment with one replica by default
- ClusterIP Service exposing port 8765
- TCP readiness and liveness probes on port 8765

The chart does not create Secrets, ConfigMaps, Ingresses, PersistentVolumeClaims, ServiceAccounts, or Helm dependency resources.

## Install

```bash
helm upgrade --install py3o ./py3o \
  --namespace py3o \
  --create-namespace
```

Example with two replicas and another image:

```bash
helm upgrade --install py3o ./py3o \
  --namespace py3o \
  --create-namespace \
  --set replicaCount=2 \
  --set image.py3o.repository=registry.example.com/team/py3o \
  --set-string image.py3o.tag=1.0.0
```

## Main values

| Value | Default | Purpose |
|---|---:|---|
| `replicaCount` | `1` | Deployment replicas |
| `image.py3o.repository` | `xcgd/py3o` | Container image repository |
| `image.py3o.tag` | `1.0.0` | Container image tag |
| `resources.py3o` | — | Resource requests and limits |
| `nodeSelector`, `affinity`, `tolerations` | empty | Pod scheduling |
| `additionalLabels` | empty | Extra Pod labels |

## Notes

- The Service defaults to `ClusterIP`; no Ingress is created.
- `services.py3o.targetPort` and `image.pullPolicy` exist in `values.yaml` but are not consumed by the current templates.
- Resource names default to `py3o`; use `nameOverride` to avoid collisions when installing multiple releases into the same namespace.
- The current chart has no `imagePullSecrets` support. Private registry access must be managed outside the chart or added to the chart.
