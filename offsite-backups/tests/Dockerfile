# Test data for the offsite-backups filestore job, preloaded at build time:
# identical files (counts: create_local_files in preload.sh) on the source
# and on the offsite, in a single image started with a different command:
#   azurite-blob ...    -> source  (Azure Blob emulator), data in /data/azurite
#   rclone serve s3 ... -> offsite (S3),                  data in /data/s3
#
# Containers write on top of the image, so recreating them brings every
# test back to this exact state.

# [DO NOT MERGE] rclone built with the fix of
# https://github.com/rclone/rclone/pull/10253
FROM golang:1.26-alpine AS rclone-build
ARG RCLONE_COMMIT=bf8445f7c37b81ca57189ae0a0e84113baf59ea5
ADD https://github.com/divad1196/rclone/archive/${RCLONE_COMMIT}.tar.gz /rclone.tar.gz
RUN mkdir /src && tar -xzf /rclone.tar.gz -C /src --strip-components=1 \
    && cd /src && CGO_ENABLED=0 go build -o /rclone .

FROM rclone/rclone:latest AS rclone
COPY --from=rclone-build /rclone /usr/local/bin/rclone

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
