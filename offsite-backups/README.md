# offsite-backups

Runs scheduled `rclone` backups from Azure Blob Storage to an offsite S3 or Swift backend. It backs up Celebrimbor storage and Filestore containers.

## Prerequisites

- Helm 3 and Kubernetes.
- External Secrets Operator with `SecretStore` and `ExternalSecret` CRDs.
- Azure Workload Identity and Key Vault access for the configured ServiceAccounts.
- Nodes matching the chart's fixed `miscapps` / `prod` selector.
- Network access to Azure Blob Storage, Azure Key Vault, and the selected offsite provider.

## Resources created

- Four ServiceAccounts
- Azure Key Vault SecretStore and two ExternalSecrets
- Two ConfigMaps
- Daily Celebrimbor and Filestore backup CronJobs

Both CronJobs run at midnight, retry once, and retain completed Jobs for 24 hours.

## Required values

```yaml
keyvaultName: my-key-vault
identity:
  tenantID: "<azure-tenant-id>"
  clientID: "<key-vault-reader-client-id>"
  clientID_celebrimbor: "<celebrimbor-client-id>"
  clientID_filestore: "<filestore-client-id>"
  clientID_filestore_restore: "<restore-client-id>"
offsiteStorageKind: s3 # or swift
```

For `s3`, Key Vault must provide `OFFSITE-S3-ACCESS-KEY` and `OFFSITE-S3-SECRET-KEY`. For `swift`, it must provide `OFFSITE-SWIFT-USER`, `OFFSITE-SWIFT-KEY`, and `OFFSITE-SWIFT-TENANT`. The chart also needs `CELEBRIMBOR-ACCOUNT`, `CELEBRIMBOR-STORAGE`, and `FILESTORE-ACCOUNT`.

## Install

```bash
helm upgrade --install offsite-backups ./offsite-backups \
  --namespace backups \
  --create-namespace \
  --values values.yaml
```

## Operational notes

- Supported `offsiteStorageKind` values are `s3` and `swift`; the chart does not currently validate this value.
- The S3 and Swift endpoint settings are chart-defined for Exoscale and OVH respectively.
- The Filestore backup excludes containers ending in `-lab` and `-integration`.
- The chart uses `rclone/rclone:latest`; validate image policy requirements in the target environment.
