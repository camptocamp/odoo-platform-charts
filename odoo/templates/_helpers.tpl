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
- name: DB_HOST
  valueFrom:
    secretKeyRef:
      name: {{ .Values.odoo.db.hostSecret.name | quote }}
      key: {{ .Values.odoo.db.hostSecret.key | quote }}
- name: DB_NAME
  valueFrom:
    secretKeyRef:
      name: {{ .Values.odoo.db.nameSecret.name | quote }}
      key: {{ .Values.odoo.db.nameSecret.key | quote }}
- name: DB_USER
  valueFrom:
    secretKeyRef:
      name: {{ .Values.odoo.db.userSecret.name | quote }}
      key: {{ .Values.odoo.db.userSecret.key | quote }}
- name: DB_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ .Values.odoo.db.passwordSecret.name | quote }}
      key: {{ .Values.odoo.db.passwordSecret.key | quote }}
- name: DB_PORT
  value: {{ .Values.odoo.db.port | default "5432" | quote }}
- name: DB_MAXCONN
  value: {{ .Values.odoo.db.max_conn | default "5" | quote }}
{{- if .Values.odoo.redis.enabled }}
- name: ODOO_SESSION_REDIS_HOST
  valueFrom:
    secretKeyRef:
      name: {{ .Values.odoo.redis.hostSecret.name | quote }}
      key: {{ .Values.odoo.redis.hostSecret.key | quote }}
- name: ODOO_SESSION_REDIS_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ .Values.odoo.redis.passwordSecret.name | quote }}
      key: {{ .Values.odoo.redis.passwordSecret.key | quote }}
{{- end }}
{{- end }}
