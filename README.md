# Odoo Platform Helm Charts

This repository contains the Helm charts used to deploy Odoo Platform services to Kubernetes.

## Deployment model

Each chart can be deployed from a local checkout. Changed charts in pull requests are also published as Helm OCI preview artifacts in GitHub Container Registry (GHCR).

A preview artifact uses this reference:

```text
oci://ghcr.io/<owner>/odoo-platform-charts/<chart>
```

Its version is the chart version from `Chart.yaml` followed by the pull-request number. For example, a change to Odoo chart version `5.5.1` in pull request `42` is available as `5.5.1-pr.42`.

```bash
helm upgrade --install odoo \
  oci://ghcr.io/<owner>/odoo-platform-charts/odoo \
  --version 5.5.1-pr.42 \
  --namespace odoo \
  --create-namespace \
  --values values.yaml
```

These are Helm OCI charts, not Docker images. Use `helm pull`, `helm template`, `helm install`, or `helm upgrade`; do not use `docker pull`.

## Deploying a chart

1. Read the chart-specific `README.md` and review its `values.yaml`.
2. Create the target namespace and any prerequisite Secrets, External Secrets, identities, or cluster-level CRDs required by that chart.
3. Render the release before applying it:

   ```bash
   helm dependency build <chart>
   helm lint <chart>
   helm template <release> <chart> --namespace <namespace> --values values.yaml
   ```

4. Install or upgrade the release:

   ```bash
   helm upgrade --install <release> <chart> \
     --namespace <namespace> \
     --create-namespace \
     --values values.yaml
   ```

5. Verify the deployment:

   ```bash
   kubectl -n <namespace> get pods,svc
   helm -n <namespace> status <release>
   ```

6. Roll back or uninstall when needed:

   ```bash
   helm -n <namespace> history <release>
   helm -n <namespace> rollback <release> <revision>
   helm -n <namespace> uninstall <release>
   ```

## Charts

| Chart | Purpose | Documentation |
|---|---|---|
| `autossh` | SSH tunnel workload | [`autossh/README.md`](autossh/README.md) |
| `celebrimbor` | Celebrimbor application with Azure Key Vault integration | [`celebrimbor/README.md`](celebrimbor/README.md) |
| `kwkhtmltopdf` | HTML-to-PDF rendering service | [`kwkhtmltopdf/README.md`](kwkhtmltopdf/README.md) |
| `mailpit` | SMTP testing service with web UI | [`mailpit/README.md`](mailpit/README.md) |
| `odoo` | Odoo application platform chart | [`odoo/README.md`](odoo/README.md) |
| `offsite-backups` | Scheduled offsite backups | [`offsite-backups/README.md`](offsite-backups/README.md) |
| `odyssey` | PostgreSQL connection pooler/proxy | [`odyssey/README.md`](odyssey/README.md) |
| `py3o` | Py3o document generation service | [`py3o/README.md`](py3o/README.md) |

## Pull-request previews and releases

Pull requests run commit-message validation and package every changed chart. Internal feature and fix pull requests publish preview charts to GHCR using `<chart-version>-pr.<PR-number>` versions. Release Please pull requests are excluded from preview publication because they produce final releases instead.

Release Please runs on `master`. It creates a release pull request for each changed chart, updates the chart version and changelog, and creates a `<chart>-<version>` Git tag when that release pull request is merged.

After a Release Please release PR is merged, the final publisher runs after Release Please completes. It builds the chart from the matching `<chart>-<version>` Git tag and publishes it to GHCR with the final `<chart-version>` OCI tag.

## Contributing a chart

- Keep chart-specific deployment requirements in that chart's `README.md`.
- Use Conventional Commit messages such as `fix:` and `feat:`.
- Add a `CHANGELOG.md` and register a new chart in the Release Please configuration and manifest.
- Do not place production credentials in committed values files.
