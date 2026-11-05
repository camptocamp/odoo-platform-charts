#!/bin/sh
# Preloads the benchmark data into the images (called by the Dockerfile):
#   preload-azurite | preload-s3
#
# POSIX sh: the Alpine images used by the containers have no bash.
set -e

MTIME="2026-01-01 00:00:00"

# Same content + same modification time on both images, so the files are
# equal for --checksum (MD5) and for master's default (size + modtime).
# $2 files in directory $1, by batches of 500, 8 batches in parallel.
create_files() {
  mkdir -p "$1"
  seq 0 $(($2 - 1)) | MTIME=$MTIME xargs -n 500 -P 8 sh -c '
    for i; do
      echo "$i" > "$0/f$i"
      touch -d "$MTIME" "$0/f$i"
    done' "$1"
}

# The data of both images, created locally in directory $1: one
# subdirectory per storage container.
create_local_files() {
  create_files "$1/cust-a-prod" 10000
  create_files "$1/cust-b-prod" 3000
  create_files "$1/cust-c-lab" 3000  # excluded by the job (-lab)
}

# Image build: the same data in both images, only the push method differs.
preload_azurite() {
   start_azurite; 
  dir=$(mktemp -d)
  create_local_files "$dir"
  rclone move --transfers 64 --checkers 64 "$dir" azure:
  stop_azurite
}

preload_s3() {
  dir=$(mktemp -d)
  create_local_files "$dir"
  mkdir -p /data/s3
  mv "$dir"/* /data/s3/
}

# Azurite must run while pushing. It writes its index
# (__azurite_db_blob__.json) only on clean exit: SIGTERM + wait,
# otherwise the image has no data.
start_azurite() {
  azurite-blob --location /data/azurite --blobHost 0.0.0.0 \
    --loose --skipApiVersionCheck >/dev/null &
  azurite_pid=$!
  until rclone lsd azure: >/dev/null 2>&1; do sleep 0.2; done
}
stop_azurite() {
  kill -TERM $azurite_pid
  wait $azurite_pid || true
  test -s /data/azurite/__azurite_db_blob__.json
}

case "$1" in
  preload-azurite) preload_azurite ;;
  preload-s3) preload_s3 ;;
  *) sed -n '2,13p' "$0"; exit 1 ;;
esac
