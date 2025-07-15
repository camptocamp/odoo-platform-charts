{{- define "odoo.internal-resources-thread" -}}
  {{- if (eq .instance_type "xlarge") }}
LIMIT_MEMORY_SOFT: {{ .override.memory_soft | default "1610612736" | quote }}
LIMIT_MEMORY_HARD: {{ .override.memory_hard | default "2097152000" | quote }}
WORKERS: "0"
  {{- else if (eq .instance_type "large") }}
WORKERS: "0"
LIMIT_MEMORY_SOFT: {{ .override.memory_soft | default "1073741824" | quote }}
LIMIT_MEMORY_HARD: {{ .override.memory_hard | default "1610612736" | quote }}
  {{- else}}
WORKERS: "0"
LIMIT_MEMORY_SOFT: {{ .override.memory_soft | default "750117120" | quote }}
LIMIT_MEMORY_HARD: {{ .override.memory_hard | default "943718400" | quote }}
  {{- end }}
{{- end -}}


{{- define "odoo.physical-resources-thread" -}}
  {{- if eq .Values.odoo.instance_type "xlarge" -}}
requests:
  cpu: 0.05
  memory: 360Mi
limits:
  cpu: {{ .Values.odoo.override_resources.cpu | default 4 }}
  memory: {{ .Values.odoo.override_resources.memory | default "2Gi" }}
  {{- else if eq .Values.odoo.instance_type "large" -}}
requests:
  cpu: 0.025
  memory: 200Mi
limits:
  cpu: {{ .Values.odoo.override_resources.cpu | default 2 }}
  memory: {{ .Values.odoo.override_resources.memory | default "1.5Gi" }}
  {{- else -}}
requests:
  cpu: 0.025
  memory: 200Mi
limits:
  cpu: {{ .Values.odoo.override_resources.cpu | default 1 }}
  memory: {{ .Values.odoo.override_resources.memory | default "1.2Gi" }}
  {{- end }}
{{- end }}
