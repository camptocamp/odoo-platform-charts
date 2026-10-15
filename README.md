# Odoo Platform Helm Charts

This repository contains the Helm charts used to deploy Odoo Platform services to Kubernetes.

## Deployment model

Each chart can be deployed from a local checkout. Changed charts in pull requests are also published as Helm OCI preview artifacts in GitHub Container Registry (GHCR).

A preview artifact uses this reference:

```text
oci://ghcr.io/camptocamp/odoo-platform-charts/<chart>
```

Its version is the chart version from `Chart.yaml` followed by the pull-request number. For example, a change to Odoo chart version `5.5.1` in pull request `42` is available as `5.5.1-pr.42`.

```bash
helm upgrade --install odoo \
  oci://ghcr.io/camptocamp/odoo-platform-charts/odoo \
  --version 5.5.1-pr.42 \
  --namespace odoo \
  --create-namespace \
  --values values.yaml
```

These are Helm OCI charts, not Docker images. Use `helm pull`, `helm template`, `helm install`, or `helm upgrade`; do not use `docker pull`.

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

## Working on a chart

1. Create a branch and change the chart templates, values, dependencies, and chart-specific `README.md` as needed.
2. Do not manually change the Helm chart `version:` in `Chart.yaml`. Release Please manages that version.
3. Update `appVersion:` in `Chart.yaml` when the underlying application version changes. This is application metadata and remains a manual change.
4. Validate locally before opening a pull request:

   ```bash
   helm dependency build <chart>
   helm lint <chart>
   helm template <release> <chart> --namespace <namespace> --values values.yaml
   ```

5. Use a Conventional Commit message so Release Please can calculate the next chart version:

   ```text
   fix(odoo): correct session configuration
   feat(mailpit): add SMTP TLS option
   ```

6. Open a pull request against `master`. After its preview workflow completes, test the published preview chart if needed:

   ```bash
   helm upgrade --install <release> \
     oci://ghcr.io/camptocamp/odoo-platform-charts/<chart> \
     --version <chart-version>-pr.<PR-number> \
     --namespace <namespace> \
     --create-namespace \
     --values values.yaml
   ```

Do not edit `CHANGELOG.md` or `.release-please-manifest.json` in a normal feature or fix pull request. Release Please updates them in its generated release pull request.

## CI and release pipeline

```text
Open normal PR
  → commit-message check
  → Helm lint and render validation
  → preview chart published to GHCR: x.x.x-pr.<PR-number>

Close normal PR
  → that PR's preview chart is deleted from GHCR

Merge normal PR into master
  → Release Please creates or updates a release PR

Review and merge Release Please PR
  → Chart.yaml version, CHANGELOG.md, and release manifest are updated
  → Release Please creates <chart>-<version> Git tag and GitHub Release
  → final chart is published to GHCR: x.x.x
```

The workflows responsible for this are:

| Workflow | Responsibility |
|---|---|
| `commits-checks.yaml` | Checks Conventional Commit messages on pull requests. |
| `helm-publish-pr.yaml` | Validates changed charts and publishes PR preview charts. |
| `helm-cleanup-pr-preview.yaml` | Removes only the preview charts belonging to a closed normal PR. |
| `release-please.yaml` | Creates release PRs and, after their merge, creates final tags and GitHub Releases. |
| `helm-publish-release.yaml` | Packages the immutable release tag and publishes the final OCI chart. |

## Contributing a chart

- Keep chart-specific deployment requirements in that chart's `README.md`.
- Use Conventional Commit messages such as `fix:` and `feat:`.
- Register a new chart in the Release Please configuration and manifest.
- Do not place production credentials in committed values files.
