{{- define "odoo.internal-resources-cron" -}}
  {{- if (eq .instance_type "xlarge") }}
WORKERS: {{ .override.workers | default "2" | quote }}
LIMIT_MEMORY_SOFT: {{ .override.memory_soft | default "1610612736" | quote }}
LIMIT_MEMORY_HARD: {{ .override.memory_hard | default "3221225472" | quote }}
  {{- else if (eq .instance_type "large") }}
WORKERS: {{ .override.workers | default "1" | quote }}
LIMIT_MEMORY_SOFT: {{ .override.memory_soft | default "1073741824" | quote }}
LIMIT_MEMORY_HARD: {{ .override.memory_hard | default "2684354560" | quote }}
  {{- else}}
WORKERS: {{ .override.workers | default "1" | quote }}
LIMIT_MEMORY_SOFT: {{ .override.memory_soft | default "750117120" | quote }}
LIMIT_MEMORY_HARD: {{ .override.memory_hard | default "2097152000" | quote }}
  {{- end }}
{{- end -}}

{{- define "odoo.physical-resources-cron" -}}
  {{- if eq .Values.odoo.instance_type "xlarge" -}}
requests:
  cpu: 0.1
  memory: 360Gi
limits:
  cpu: {{ .Values.odoo.cron.override_resources.cpu | default 4 }}
  memory: {{ .Values.odoo.cron.override_resources.memory | default "3.5Gi" }}
{{- else if eq .Values.odoo.instance_type "large" -}}
requests:
  cpu: 0.1
  memory: 200Mi
limits:
  cpu: {{ .Values.odoo.cron.override_resources.cpu | default 2 }}
  memory: {{ .Values.odoo.cron.override_resources.memory | default "3Gi" }}
  {{- else -}}
requests:
  cpu: 0.1
  memory: 200Mi
limits:
  cpu: {{ .Values.odoo.cron.override_resources.cpu | default 1 }}
  memory: {{ .Values.odoo.cron.override_resources.memory | default "2Gi" }}
  {{- end }}
{{- end }}
