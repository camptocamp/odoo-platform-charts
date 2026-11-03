#!/bin/sh
# Benchmark of the rclone copy of the offsite-backups filestore job.
# Runs in the "benchmark" container, from offsite-backups/tests:
#   docker compose run --rm benchmark benchmark-chart-command
#   docker compose down                    back to the preloaded data
#
# Subcommands (each injects drift on Azurite, then runs + measures):
#   benchmark-chart-command  the job of the local chart
#   benchmark-rclone-before  rclone copy without the PR 212 flags
#   benchmark-rclone-after   rclone copy with the PR 212 flags
#
# POSIX sh: the Alpine images used by the containers have no bash.
set -e

# Drift between Azurite and S3: EDITED files of cust-a-prod changed on
# Azurite only, so the copy has something to do.
inject_drift_on_azurite() {
  seq 0 $((EDITED - 1)) | xargs -P 8 -I {} sh -c \
    'echo "edited {}" | rclone rcat azure:cust-a-prod/f{}'
}

# rclone copy of container $1, before / after the PR 212 flags.
rclone_copy_before() {
  rclone copy "azure:$1" "offsite:$1"
}
rclone_copy_after() {
  rclone copy --checksum --stats 2h --stats-log-level NOTICE "azure:$1" "offsite:$1"
}

# The job of offsite-backups/templates/backup-filestore.yaml, with
# rclone_copy_$1 (before / after): every container except -lab and
# -integration in parallel (the job caps at 5; here there are only 2),
# fails if one copy fails.
run_job() {
  pids=""
  for bucket in $(rclone lsf "azure:" | grep -v -e '\-lab\/$' \
      | grep -v -e '\-integration\/$' | tr -d '/'); do
    rclone_copy_$1 "$bucket" &
    pids="$pids $!"
  done
  for pid in $pids; do wait "$pid"; done
}

# Duration, HEAD requests sent to S3 and number of copied files of the job
# with rclone_copy_$1 (before / after).
benchmark_rclone_copy() {
  start=$(date +%s)
  run_job "$1"
  echo "=== $1: $(( $(date +%s) - start ))s," \
    "$(grep -c 'HEAD /cust-' "$RCLONE_LOG_FILE" || true) HEAD requests," \
    "$(grep -c 'Copied (' "$RCLONE_LOG_FILE" || true) files copied"
}

# Runs the CronJob of the local chart (templates/backup-filestore.yaml,
# mounted at /chart) as written: its run-copy.sh (ConfigMap) at
# /scripts/run-copy.sh, then its args.
run_chart_command() {
  mkdir -p /scripts
  awk '/run-copy.sh: \|/{f=1;next} f&&/^---/{exit} f{sub(/^    /,"");print}' \
    /chart/backup-filestore.yaml > /scripts/run-copy.sh
  awk '/^ *args:/{a=1;next} a&&/^ *- \|/{f=1;next} f&&/^ *env:/{exit} f{sub(/^              /,"");print}' \
    /chart/backup-filestore.yaml > /tmp/args.sh
  sh /tmp/args.sh
}

# Duration, HEAD requests sent to S3 and number of copied files of the
# chart command.
benchmark_chart_command() {
  start=$(date +%s)
  run_chart_command
  echo "=== chart: $(( $(date +%s) - start ))s," \
    "$(grep -c 'HEAD /cust-' "$RCLONE_LOG_FILE" || true) HEAD requests," \
    "$(grep -c 'Copied (' "$RCLONE_LOG_FILE" || true) files copied"
}

case "$1" in
  benchmark-chart-command) inject_drift_on_azurite; benchmark_chart_command ;;
  benchmark-rclone-before) inject_drift_on_azurite; benchmark_rclone_copy before ;;
  benchmark-rclone-after) inject_drift_on_azurite; benchmark_rclone_copy after ;;
  *) sed -n '2,13p' "$0"; exit 1 ;;
esac
