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
- name: DB_MAXCONN
  value: {{ .Values.odoo.db.max_conn | default "5" | quote }}
{{- if .Values.odoo.redis.enabled }}
- name: ODOO_SESSION_REDIS_URL
  valueFrom:
    secretKeyRef:
      name: {{ .Values.odoo.redis.secret.name | quote }}
      key: {{ .Values.odoo.redis.secret.url | quote }}
{{- end }}
{{- end }}


{{/*
Resources configuration according to instance type
*/}}
{{- define "odoo.physical-resources" -}}
{{- if eq .Values.odoo.instance_type "xlarge" -}}
requests:
  cpu: 0.1
  memory: 1.2Gi
limits:
  cpu: {{ .Values.odoo.override_resources.cpu | default 1 }}
  memory: {{ .Values.odoo.override_resources.memory | default "3.5Gi" }}
{{- else if eq .Values.odoo.instance_type "large" -}}
requests:
  cpu: 0.1
  memory: 650Mi
limits:
  cpu: {{ .Values.odoo.override_resources.cpu | default 0.7 }}
  memory: {{ .Values.odoo.override_resources.memory | default "3Gi" }}
  {{- else if eq .Values.odoo.instance_type "smartcamp" -}}
requests:
  cpu: 0.1
  memory: 650Mi
limits:
  cpu: {{ .Values.odoo.override_resources.cpu | default 0.35 }}
  memory: {{ .Values.odoo.override_resources.memory | default "1Gi" }}
{{- else -}}
requests:
  cpu: 0.1
  memory: 650Mi
limits:
  cpu: {{ .Values.odoo.override_resources.cpu | default 0.5 }}
  memory: {{ .Values.odoo.override_resources.memory | default "2.2Gi" }}
{{- end }}
{{- end }}


{{/*
Odoo specific resources configuration according to instance type
*/}}
{{- define "odoo.internal-resources" -}}
{{- if or (eq .Values.odoo.instance_type "xlarge") (eq .Values.odoo.instance_type "large") }}
LIMIT_MEMORY_SOFT: {{ .Values.odoo.override_limits.memory_soft | default "650117120" | quote }}
LIMIT_MEMORY_HARD: {{ .Values.odoo.override_limits.memory_hard | default "4194304000" | quote }}
WORKERS: {{ .Values.odoo.override_limits.workers | default "14" | quote }}
{{- else if eq .Values.odoo.instance_type "smartcamp" }}
LIMIT_MEMORY_SOFT: {{ .Values.odoo.override_limits.memory_soft | default "325058560" | quote }}
LIMIT_MEMORY_HARD: {{ .Values.odoo.override_limits.memory_hard | default "1048576000" | quote }}
WORKERS: {{ .Values.odoo.override_limits.workers | default "4" | quote }}
{{- else }}
LIMIT_MEMORY_SOFT: {{ .Values.odoo.override_limits.memory_soft | default "650117120" | quote }}
LIMIT_MEMORY_HARD: {{ .Values.odoo.override_limits.memory_hard | default "2097152000" | quote }}
WORKERS: {{ .Values.odoo.override_limits.workers | default "7" | quote }}
{{- end }}
{{- end }}
