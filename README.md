# odoo-platform-charts

Camptocamp Odoo charts intended to be used on Azure K8s cluster

## How to build a new chart version

### Prerequisites

* [Helm](https://helm.sh/docs/intro/install)

### Commands

```bash
helm package odoo
helm repo index .
```
