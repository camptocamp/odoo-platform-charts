{{/*
Expand the name of the chart.
*/}}
{{- define "odoo.name" -}}
{{- printf "%s-odoo-%s" .Values.odoo.customerName .Values.odoo.env }}
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
  cpu: 0.35
  memory: 1.2Gi
limits:
  cpu: 1
  memory: 3.5Gi
{{- else if eq .Values.odoo.instance_type "large" -}}
requests:
  cpu: 0.35
  memory: 650Mi
limits:
  cpu: 0.7
  memory: 3Gi
{{- else -}}
requests:
  cpu: 0.35
  memory: 650Mi
limits:
  cpu: 0.5
  memory: 2.2Gi
{{- end }}
{{- end }}


{{/*
Odoo specific resources configuration according to instance type
*/}}
{{- define "odoo.internal-resources" -}}
LIMIT_MEMORY_SOFT: "650117120"
{{- if or (eq .Values.odoo.instance_type "xlarge") (eq .Values.odoo.instance_type "large") }}
LIMIT_MEMORY_HARD: "4194304000"
WORKERS: "14"
{{- else }}
LIMIT_MEMORY_HARD: "2097152000"
WORKERS: "7"
{{- end }}
{{- end }}
