# odoo-platform-charts

Camptocamp Odoo charts intended to be used on Azure K8s cluster.

## Branch policy

`master` is the stable release branch. Feature work should be proposed through pull requests; fixes may target the appropriate stable branch according to the maintenance policy.

## Automated chart releases

Chart versions and changelogs are managed by Release Please. Do not manually edit a chart's `version` field after this automation is enabled.

Each source chart has its own `CHANGELOG.md`. Conventional Commit messages determine the next release and changelog entry:

- `fix:` creates a patch release;
- `feat:` creates a minor release once the chart is 1.0.0 or later; for a 0.x chart it creates a patch release;
- a Conventional Commit breaking-change marker creates a major release once the chart is 1.0.0 or later; for a 0.x chart it creates a minor release.

On pull requests targeting `master`, CI detects changed chart directories, builds dependencies, runs `helm lint`, renders templates, packages the charts, and uploads the packages as workflow artifacts.

After a chart change merges to `master`, Release Please opens a chart-specific release pull request. Merging that release pull request updates the chart version and changelog, creates a `<chart>-<version>` Git tag, packages each newly released chart at the repository root, and merges it into `index.yaml`.

The release workflows require the GitHub App credentials already used by the Shelter release automation:

- `SHELTER_MAINTAINER_CLIENT_ID`
- `SHELTER_MAINTAINER_PRIVATE_KEY`

The app must be able to create pull requests, write repository contents, and push the generated `.tgz` files and `index.yaml` update to `master`. If `master` is protected, grant that app the narrowly scoped bypass required for the publication commit.

## Adding a new chart

1. Add the chart directory with `Chart.yaml`, templates, values, and `CHANGELOG.md`.
2. Add the chart name and initial published version to both Release Please files.
3. Ensure the initial chart version matches the manifest value.
4. Use Conventional Commits for future changes.

## Local verification

```bash
helm dependency build <chart>
helm lint <chart>
helm template <chart> <chart>
helm package <chart>
```


## Release workflow implementation

The workflows execute in the following order:

1. A normal pull request targets `master`.
   - `commits-checks` validates Conventional Commit messages.
   - `helm-validate-pr` detects changed chart directories and, for each changed chart, builds dependencies, runs `helm lint`, renders templates, packages the chart, and uploads the archive as a pull-request artifact.
   - These two checks run in parallel.

2. The normal pull request merges into `master`.
   - `release-please` reads the changes since each chart's previous release.
   - It creates or updates an independent release pull request for every chart that needs a version bump.
   - No permanent `.tgz` archive or `index.yaml` update is made at this point.

3. A Release Please pull request is merged into `master`.
   - The release PR updates the chart's `Chart.yaml` version, its `CHANGELOG.md`, and `.release-please-manifest.json`.
   - Release Please creates the corresponding `<chart>-<version>` Git tag and GitHub release.
   - `helm-publish-release` detects the manifest version change, waits for the release tag, then packages the chart from that exact tag in a temporary Git worktree.
   - The publisher merges the new archive into the root Helm repository with `helm repo index --merge index.yaml` and commits the resulting `<chart>-<version>.tgz` plus `index.yaml` to `master`.

Publication jobs are serialized because every release modifies the shared root `index.yaml`. The publisher packages from the immutable release tag rather than the moving `master` branch, ensuring that each archive corresponds exactly to its versioned release.
