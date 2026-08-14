# Odoo Chart Changelog

## [5.4.0] - 2026-08-14

- new feature release, with 5.4.x meant to be used with docker-odoo-project 5.4.x
- documentation update

## [5.3.11] - 2026-08-07

- Normalize threaded default memory limits
- Use new wildcard cache rules in ACR

## [5.3.10] - 2026-08-04 — BROKEN

- Stop passing gosu commands to container entrypoint
- Allow setting `secureCookies` in `odoo.nginx` object
- Document `nginx.pdfContent` and `nginx.cacheSize` values
- Create Odoo version label from `odoo.odoo_version`
- Fix missing `topologySpreadConstraint` on odooqueue containers
- Clean-up deployment.yaml and `_deployment_helpers.tpl`

## [5.3.9] - 2026-04-21 — BROKEN

- Do not set `SERVER_WIDE_MODULES` by default; let Odoo use its own defaults (#167)

## [5.3.8] - 2026-04-15 — BROKEN

- Fix db filter issue on old instances (#166)

## [5.3.7] - 2026-04-15

- Fix Chart definition overwrite

## [5.3.6] - 2026-04-14

- Disable `DB_FILTER` by default to avoid unintended database listing (#165)
- Allow setting resource requests on the chart (#163)

## [5.3.5] - 2026-03-12

- Change werkzeug log level from `ERROR` to `INFO`
- Refactor preinit-manager configuration

## [5.3.4] - 2025-11-17

- Reduce CPU request values for cron, thread, and worker pods on `xlarge` and `large` instance types (#157)

## [5.3.3] - 2025-07-14

- `SERVER_WIDE_MODULES` is now version-aware: `attachment_azure` is only included for Odoo ≤ 17.0 (#154)
- Update resource limits for instance types

## [5.3.2] - 2025-06-24

- Increase default max connections for cron and thread pods

## [5.3.1] - 2025-06-04

- Fix 2 cron workers not being applied in hybrid modes (#150)
- Remove duplicated `DB_MAXCONN` environment variable
- Update Odoo readiness probe configuration for improved responsiveness
- Fix thread memory limit value

## [5.3.0] - 2025-04-24

- Add support for per-component resource tuning via `odoo.cron.override_limits`, `odoo.queuejob.override_limits` etc. (#149)

## [5.2.3] - 2025-04-14

- Add support for the `service` component type

## [5.2.2] - 2025-03-31

- Fix celebrimbor namespace issue (#146)

## [5.2.1] - 2025-03-27

- Fix report URL being overwritten (#145)

## [5.2.0] - 2025-03-17

- Rename `IPWhiteList` middlewares to `IPAllowList` to follow Traefik v3 naming (#140)
- Enable network policy by default; rework restricted-service logic (#141)

## [5.1.0] - 2025-02-10

- Make the kwkhtmltopdf network policy rule configurable

## [5.0.0] - 2025-02-06 — BREAKING CHANGE

- Change Traefik `apiVersion` from `traefik.containo.us` to `traefik.io`

## [4.0.7] - 2025-02-06

- Fix init container

## [4.0.6] - 2025-02-04

- Fix health env variable not being set for multi-thread pods (#132)

## [4.0.5] - 2024-11-11

- Add hybrid mode for multi-thread support

## [3.7.4] - 2024-12-13

- Use Azure CDN cache rules and specify curl image explicitly (#125)
- Fix odoo deployment (#122)

## [3.7.0] - 2024-10-22

- Allow adding custom labels to all deployed objects

## [3.6.0] - 2024-10-09

- Increase default CPU values for `packaged` and `indexed` instance types

## [3.5.11] - 2024-09-05

- Fix longpolling configuration in nginx (#114)
- Add namespace selector for debug printserver (#113)
- Fix Odoo container CMD override
- Allow the Prometheus server (not only the Prometheus operator) to scrape odoo pods

## [3.5.8] - 2024-07-31

- Add optional `securityContext` configuration
- Fix volumes definitions
- Add network policies
- Remove network policy restriction for queuejob

## [3.4.0] - 2024-04-09

- Add support for Pod Disruption Budgets (`podDisruptionBudget`)
- Support new Odoo images that do not require gosu

## [3.3.0] - 2024-02-13

- Disable `serviceMonitor` generation by default
- Allow restarting the instance on a schedule when the database has expired
- Add configmap hash annotation to trigger pod restarts on nginx config change
- Fix IngressRoute template context and HSTS middleware naming
- Remove empty values from templates to avoid ArgoCD out-of-sync false positives

## [3.2.2] - 2023-09-12

- Add nginx configuration options

## [3.2.1] - 2023-09-11

- Bump preinit-manager image tag

## [3.2.0] - 2023-08-30

- Add `odoo.healthz` configuration value
- Add security headers to nginx
- Enable Azure Workload Identity support

## [2.1.0] - 2023-02-21

- **Breaking**: New ingress configuration structure
- Add rolling update release strategy
- Add global 404 error page service

## [1.5.6] - 2023-01-30

- Add configmap hash to healthz annotations in odooqueue

## [1.5.5] - 2023-01-30

- Add configmap hash annotation for odoohealthz config
- Add resource limits for odoohealthz

## [1.5.4] - 2023-01-18

- Disable readiness probe for queuejob pod

## [1.5.3] - 2022-12-20

- Enable liveness and readiness probes on odoo pods by default

## [1.5.0] - 2022-11-08

- Add health `serviceMonitor` for odoo
- Enable "do not index me" (`X-Robots-Tag`) by default on all ingress routes (opt-out)

## [1.4.0] - 2022-10-25

- Add `odoohealthz` sidecar support
- Add health check on odooqueue
- Enable team power user RBAC role
- Add ability to configure `pathPrefixes` in rate-limits
- Update backup-manager to v1.0.0

## [1.2.7] - 2022-06-09

- WAF: add Traefik middleware for HTTP→HTTPS redirection

## [1.2.4] - 2022-05-16

- Add missing resource name suffixes for lab deployments
- Remove unused ingress resource and values
- Set `revisionHistoryLimit` to 3

## [1.2.x] - 2022-03 to 2022-05

- Add `additionalAnnotations` to odooqueue deployment
- Fix `LOG_HANDLER` default value for Azure libraries
- Add `connector_module` value for odooqueue service
- Fix deploy strategy for queuejob pod
- Fix unaccent env variable handling

## [1.1.0] - 2022-03

- Implement auto-backup
- Implement auto-dump
- Fix `LIMIT_MEMORY_SOFT` in Marabunta init container

## [1.0.0] - 2022-02

- **Breaking**: Refactor ingress routes
- Spread odoo pods through nodes by default (#11)
- Add support for Traefik `IngressRoute`
- Add support for role bindings
- Add resource allocation overrides
- Ensure deployments restart after config or secret changes
- Fix `SERVER_WIDE_MODULES` for queuejob pod
- Set `azure` log handler to `ERROR` level

## [0.x] - 2021

- Initial chart with odoo, odooqueue, and Marabunta init container
- Basic ingress, secret, and configmap templates
- Instance sizing with fixed choices (`S`, `M`, `L`, `XL`)
- `PGCLIENTENCODING` set to `UTF8`
- `SERVER_ENV_CONFIG` support
