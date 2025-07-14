{{- define "odoo.config" }}
apiVersion: v1
kind: ConfigMap
metadata:
  name: odoo-config{{- include "odoo-cs-suffix" . }}-{{ .pod_type }}
  labels:
    {{- include "odoo.labels" $ | nindent 4 }}
data:
  ODOO_BASE_URL: {{ .Values.odoo.base_url | default "http://localhost:8069" }}
  ODOO_REPORT_URL: {{ .Values.odoo.report_url | default "http://localhost:8069" }}
  {{- if .Values.odoo.storage.use_aad }}
  AZURE_STORAGE_USE_AAD: '1'
  AZURE_STORAGE_ACCOUNT_URL: {{ .Values.odoo.storage.account_url }}
  {{- else if .Values.odoo.storage.connection_string }}
  AZURE_STORAGE_CONNECTION_STRING: {{ .Values.odoo.storage.connection_string }}
  {{- else }}
  AZURE_STORAGE_ACCOUNT_NAME: {{ .Values.odoo.storage.account_name }}
  AZURE_STORAGE_ACCOUNT_URL: {{ .Values.odoo.storage.account_url }}
  AZURE_STORAGE_ACCOUNT_KEY: {{ .Values.odoo.storage.account_key }}
  {{- end }}
  {{- if eq .pod_type "cron" }}
    {{- include "odoo.internal-resources-cron" (dict "override" .Values.odoo.cron.override_limits "instance_type" .Values.odoo.instance_type) | nindent 2 }}
  {{- else if eq .pod_type "thread"}}
    {{- include "odoo.internal-resources-thread" (dict "override" .Values.odoo.override_limits "instance_type" .Values.odoo.instance_type) | nindent 2 }}
  {{- else if eq .pod_type "queuejob"}}
    {{- include "odoo.internal-resources-queuejob" (dict "override" .Values.odoo.queuejob.override_limits "instance_type" .Values.odoo.instance_type "compatibility_workers" .Values.odoo.queuejob.workers) | nindent 2 }}
  {{- else }}
    {{- include "odoo.internal-resources-worker" (dict "override" .Values.odoo.override_limits "instance_type" .Values.odoo.instance_type) | nindent 2 }}
  {{- end }}
  DEMO: {{ .Values.odoo.demo | default "False" | quote }}
  MARABUNTA_MODE: {{ .Values.odoo.marabunta.mode | default "Full" }}
  MARABUNTA_ALLOW_SERIE: {{ .Values.odoo.marabunta.allow_series | default "False" | quote }}
  MIGRATE: "False"
  ODOO_CLOUD_PLATFORM_UNSAFE: '0'
  ODOO_LOGGING_JSON: '1'
  {{- if .Values.odoo.redis.enabled }}
  ODOO_SESSION_REDIS: '1'
  ODOO_SESSION_REDIS_PREFIX: {{ include "odoo.name" . }}
  {{- end }}
  RUNNING_ENV: {{ .Values.odoo.env }}
  {{- if gt .Values.odoo.odoo_version 17.0 }}
  {{- if eq .pod_type "queuejob" }}
  SERVER_WIDE_MODULES: {{ printf "%s,queue_job" (.Values.odoo.server_wide_modules | default "web,session_redis,logging_json") }}
  {{- else }}
  SERVER_WIDE_MODULES: {{ .Values.odoo.server_wide_modules | default "web,session_redis,logging_json" }}
  {{- end }}
  {{- else }}
  {{- if eq .pod_type "queuejob" }}
  SERVER_WIDE_MODULES: {{ printf "%s,queue_job" (.Values.odoo.server_wide_modules | default "web,attachment_azure,session_redis,logging_json") }}
  {{- else }}
  SERVER_WIDE_MODULES: {{ .Values.odoo.server_wide_modules | default "web,attachment_azure,session_redis,logging_json" }}
  {{- end }}
  {{- end }}
  SERVER_ENV_CONFIG: {{ toYaml .Values.odoo.server_env_config | indent 2 | default "" }}
  LOG_HANDLER: {{ .Values.odoo.log_handler | default ":INFO,werkzeug:ERROR,azure:ERROR" }}
  LOG_LEVEL: {{ .Values.odoo.log_level | default "info" }}
  UNACCENT: {{ .Values.odoo.unaccent | default "False" | quote }}
  KWKHTMLTOPDF_SERVER_URL: {{ .Values.odoo.kwkhtmltopdf_server_url | default "http://kwkhtmltopdf.bs-kwkhtmltopdf01250:8080" }}
  PGCLIENTENCODING: UTF8
  {{- if eq .pod_type "cron" -}}
    {{- include "odoo.component-limits" (dict "compo" .Values.odoo.cron "default_max_conn" 20 "default_max_cron" "2") | nindent 2 -}}
  {{- else if eq .pod_type "thread" }}
    {{- include "odoo.component-limits" (dict "compo" .Values.odoo "default_max_conn" 20 "default_max_cron" "0") | nindent 2 -}}
  {{- else if eq .pod_type "queuejob" }}
    {{- include "odoo.component-limits" (dict "compo" .Values.odoo.queuejob "default_max_conn" 5 "default_max_cron" 0 ) | nindent  2 }}
  ODOO_QUEUE_JOB_CHANNELS: {{ .Values.odoo.queuejob.channels | default "root:2"| quote }}
  {{- else }}
    {{- include "odoo.component-limits" (dict "compo" .Values.odoo "default_max_conn" 5 "default_max_cron" "1") | nindent 2 -}}
  {{- end -}}
{{- end }}
