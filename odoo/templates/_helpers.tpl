{{/*
Expand the name of the chart.
*/}}
{{- define "odoo.name" -}}
{{- if eq .Values.odoo.env "labs" }}
{{- printf "%s-odoo-%s" .Values.odoo.customerName .Values.odoo.lab_name }}
{{- else }}
{{- printf "%s-odoo-%s" .Values.odoo.customerName .Values.odoo.env }}
{{- end }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "odoo.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "odoo.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "odoo.labels" -}}
helm.sh/chart: {{ include "odoo.chart" . }}
{{ include "odoo.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- if .Values.extraLabels }}
{{ toYaml .Values.extraLabels }}
{{- end }}
{{- end }}

{{/*
Selector labels

*/}}
{{- define "odoo.selectorLabels" -}}
app.kubernetes.io/name: {{ include "odoo.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Config/Secret suffix
*/}}
{{- define "odoo-cs-suffix" -}}
{{- if eq .Values.odoo.env "labs" }}
{{- printf "-%s" .Values.odoo.lab_name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}


{{/*
Odoo configuration to be reused within multiple pods
*/}}
{{- define "odoo.common-environment" -}}
- name: AZURE_STORAGE_NAME
  valueFrom:
    secretKeyRef:
      name: {{ .Values.odoo.storage.secret.name | quote }}
      key: {{ .Values.odoo.storage.secret.container | quote }}
- name: DB_HOST
  valueFrom:
    secretKeyRef:
      name: {{ .Values.odoo.db.secret.name | quote }}
      key: {{ .Values.odoo.db.secret.host | quote }}
- name: DB_NAME
  valueFrom:
    secretKeyRef:
      name: {{ .Values.odoo.db.secret.name | quote }}
      key: {{ .Values.odoo.db.secret.database | quote }}
- name: DB_USER
  valueFrom:
    secretKeyRef:
      name: {{ .Values.odoo.db.secret.name | quote }}
      key: {{ .Values.odoo.db.secret.user | quote }}
- name: DB_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ .Values.odoo.db.secret.name | quote }}
      key: {{ .Values.odoo.db.secret.password | quote }}
- name: DB_PORT
  value: {{ .Values.odoo.db.port | default "5432" | quote }}
  {{- if .Values.odoo.redis.enabled }}
- name: ODOO_SESSION_REDIS_URL
  valueFrom:
    secretKeyRef:
      name: {{ .Values.odoo.redis.secret.name | quote }}
      key: {{ .Values.odoo.redis.secret.url | quote }}
  {{- end }}
{{- end -}}


{{- define "odoo.component-limits" -}}
LIMIT_REQUEST: {{ .compo.limits.request | default "32000" | quote }}
LIMIT_TIME_CPU: {{ .compo.limits.time_cpu | default "86400" | quote }}
LIMIT_TIME_REAL: {{ .compo.limits.time_real | default "86400" | quote }}
LIMIT_TIME_REAL_CRON: {{ .compo.limits.time_real_cron | default "600" | quote }}
MAX_CRON_THREADS: {{ .compo.limits.max_cron | default .default_max_cron | quote }}
DB_MAXCONN: {{ .compo.db.max_conn | default .default_max_conn | quote }}
{{- end }}
