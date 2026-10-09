# odoo-platform-charts

Camptocamp Odoo charts intended to be used on Azure K8s cluster

## Branches polices

Master is the stable branch
Devel is developpement branch

PR: 
Fix PR can be on both 
Evolution PR should be done on devel

## How to build a new chart version

### Prerequisites

* [Helm](https://helm.sh/docs/intro/install)

### Commands

```bash
helm package odoo
helm repo index .
```
