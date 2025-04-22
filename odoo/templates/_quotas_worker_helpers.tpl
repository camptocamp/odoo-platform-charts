{{- define "odoo.internal-resources-worker" -}}
  {{- if (eq .instance_type "xlarge") }}
WORKERS: {{ .override.workers | default "14" | quote }}
LIMIT_MEMORY_SOFT: {{ .override.memory_soft | default "650117120" | quote }}
LIMIT_MEMORY_HARD: {{ .override.memory_hard | default "4194304000" | quote }}
  {{- else if (eq .instance_type "large") }}
WORKERS: {{ .override.workers | default "14" | quote }}
LIMIT_MEMORY_SOFT: {{ .override.memory_soft | default "650117120" | quote }}
LIMIT_MEMORY_HARD: {{ .override.memory_hard | default "4194304000" | quote }}
  {{- else}}
WORKERS: {{ .override.workers | default "7" | quote }}
LIMIT_MEMORY_SOFT: {{ .override.memory_soft | default "650117120" | quote }}
LIMIT_MEMORY_HARD: {{ .override.memory_hard | default "2097152000" | quote }}
  {{- end }}
{{- end -}}

{{- define "odoo.physical-resources-worker" -}}
  {{- if eq .Values.odoo.instance_type "xlarge" -}}
requests:
  cpu: 0.1
  memory: 1.2Gi
limits:
  cpu: {{ .Values.odoo.override_resources.cpu | default 4 }}
  memory: {{ .Values.odoo.override_resources.memory | default "3.5Gi" }}
  {{- else if eq .Values.odoo.instance_type "large" -}}
requests:
  cpu: 0.1
  memory: 650Mi
limits:
  cpu: {{ .Values.odoo.override_resources.cpu | default 2 }}
  memory: {{ .Values.odoo.override_resources.memory | default "3Gi" }}
  {{- else -}}
requests:
  cpu: 0.1
  memory: 650Mi
limits:
  cpu: {{ .Values.odoo.override_resources.cpu | default 1 }}
  memory: {{ .Values.odoo.override_resources.memory | default "2.2Gi" }}
  {{- end }}
{{- end }}
