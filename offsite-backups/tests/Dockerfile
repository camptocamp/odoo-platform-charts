# Test data for the offsite-backups filestore job, preloaded at build time:
# identical files (counts: create_local_files in preload.sh) on the source
# and on the offsite, in a single image started with a different command:
#   azurite-blob ...    -> source  (Azure Blob emulator), data in /data/azurite
#   rclone serve s3 ... -> offsite (S3),                  data in /data/s3
#
# Containers write on top of the image, so recreating them brings every
# test back to this exact state.

FROM rclone/rclone:latest AS rclone

FROM mcr.microsoft.com/azure-storage/azurite:3.33.0 AS preloaded
COPY --from=rclone /usr/local/bin/rclone /usr/local/bin/
ENV RCLONE_CONFIG_AZURE_TYPE=azureblob \
    RCLONE_CONFIG_AZURE_USE_EMULATOR=true \
    RCLONE_CONFIG_AZURE_ENDPOINT=http://127.0.0.1:10000/devstoreaccount1 \
    RCLONE_CONFIG_OFFSITE_TYPE=s3 \
    RCLONE_CONFIG_OFFSITE_PROVIDER=Rclone \
    RCLONE_CONFIG_OFFSITE_ENDPOINT=http://127.0.0.1:9000 \
    RCLONE_CONFIG_OFFSITE_ACCESS_KEY_ID=s3key \
    RCLONE_CONFIG_OFFSITE_SECRET_ACCESS_KEY=s3secret
RUN --mount=type=bind,source=preload.sh,target=/preload.sh \
    sh /preload.sh preload-azurite && sh /preload.sh preload-s3
