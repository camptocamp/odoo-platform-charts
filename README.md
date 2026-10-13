# odoo-platform-charts

Camptocamp Odoo charts intended to be used on Azure K8s cluster.

## Branch policy

`master` is the stable release branch. `devel` is the development branch. Fix pull requests may target either branch; feature pull requests should target `devel` unless the team agrees otherwise.

## Pull request preview charts in GHCR

When a pull request is opened or updated, the workflow detects every changed top-level Helm chart, builds dependencies, lints and renders the chart, then packages and publishes it as an OCI artifact to GitHub Container Registry.

Each preview uses the chart version from `Chart.yaml` with the pull request number as the SemVer prerelease identifier:

```text
<chart-version>-<PR-number>
```

For example, a pull request numbered `42` that changes the Odoo chart at version `5.5.1` is published as:

```text
oci://ghcr.io/<owner>/odoo-platform-charts/odoo --version 5.5.1-42
```

Only pull requests opened from branches in this repository can publish previews. Fork pull requests are skipped because GitHub grants them a read-only `GITHUB_TOKEN`.

## Commit linting

Every pull request runs Conventional Commit validation. Release Please uses those commit types to calculate releases and generate changelog entries:

- `fix:` creates a patch release;
- `feat:` creates a minor release once the chart is 1.0.0 or later; for a 0.x chart it creates a patch release;
- a Conventional Commit breaking-change marker creates a major release once the chart is 1.0.0 or later; for a 0.x chart it creates a minor release.

## Automated release pull requests

On every push to `master`, Release Please evaluates the configured charts and creates or updates independent release pull requests. A release pull request updates the chart's `Chart.yaml` version, its `CHANGELOG.md`, and `.release-please-manifest.json`. Merging it creates a `<chart>-<version>` Git tag and GitHub release.

This first OCI implementation publishes preview charts only. A production GHCR publishing workflow, triggered after a Release Please release, is intentionally not included yet.

## GitHub Actions permissions

The workflows use the built-in `GITHUB_TOKEN`; no external user, PAT, or GitHub App credentials are required. In repository Settings → Actions → General, enable:

- **Read and write permissions**;
- **Allow GitHub Actions to create and approve pull requests**.

If `master` is protected, allow GitHub Actions to create the release pull request and publish the release metadata, or define the required branch-protection exception.

## Adding a new chart

1. Add the chart directory with `Chart.yaml`, templates, values, and `CHANGELOG.md`.
2. Add the chart name and initial published version to both Release Please files.
3. Ensure the chart version matches the manifest value.
4. Use Conventional Commits for future changes.

## Local verification

```bash
helm dependency build <chart>
helm lint <chart>
helm template <chart> <chart>
helm package <chart>
```
