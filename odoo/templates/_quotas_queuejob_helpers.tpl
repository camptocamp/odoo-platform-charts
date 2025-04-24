{{- define "odoo.internal-resources-queuejob" -}}
  {{- if (eq .instance_type "xlarge") }}
    {{if .compatibility_workers }}
WORKERS: {{ .compatibility_workers | default "2" | quote }}
    {{ else }}
WORKERS: {{ .override.workers | default "7" | quote }}
    {{ end }}
LIMIT_MEMORY_SOFT: {{ .override.memory_soft | default "786432000" | quote }}
LIMIT_MEMORY_HARD: {{ .override.memory_hard | default "3221225472" | quote }}
  {{- else if (eq .instance_type "large") }}
    {{if .compatibility_workers }}
WORKERS: {{ .compatibility_workers | default "2" | quote }}
    {{ else }}
WORKERS: {{ .override.workers | default "5" | quote }}
    {{ end }}
LIMIT_MEMORY_SOFT: {{ .override.memory_soft | default "786432000" | quote }}
LIMIT_MEMORY_HARD: {{ .override.memory_hard | default "2684354560" | quote }}
  {{- else}}
    {{if .compatibility_workers }}
WORKERS: {{ .compatibility_workers | default "2" | quote }}
    {{ else }}
WORKERS: {{ .override.workers | default "3" | quote }}
    {{ end }}
LIMIT_MEMORY_SOFT: {{ .override.memory_soft | default "786432000" | quote }}
LIMIT_MEMORY_HARD: {{ .override.memory_hard | default "2097152000" | quote }}
  {{- end }}
{{- end -}}


{{- define "odoo.physical-resources-queuejob" -}}
  {{- if eq .Values.odoo.instance_type "xlarge" -}}
requests:
  cpu: 0.1
  memory: 1.2Gi
limits:
  cpu: {{ .Values.odoo.queuejob.override_resources.cpu | default 4 }}
  memory: {{ .Values.odoo.queuejob.override_resources.memory | default "3.5Gi" }}
{{- else if eq .Values.odoo.instance_type "large" -}}
requests:
  cpu: 0.1
  memory: 650Mi
limits:
  cpu: {{ .Values.odoo.queuejob.override_resources.cpu | default 2 }}
  memory: {{ .Values.odoo.queuejob.override_resources.memory | default "3Gi" }}
  {{- else -}}
requests:
  cpu: 0.1
  memory: 650Mi
limits:
  cpu: {{ .Values.odoo.queuejob.override_resources.cpu | default 1 }}
  memory: {{ .Values.odoo.queuejob.override_resources.memory | default "2Gi" }}
  {{- end }}
{{- end }}
