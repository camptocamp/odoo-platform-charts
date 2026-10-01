{{/*
  The hard limit matches the pod's memory limit (see below), rounded to
  1 decimal GiB, and the soft limit is always set to 85% of the hard limit
  (rounded down).

    +-----------+----------------------------+-------------------------------+
    | type      | hard                       | soft (85% of hard)            |
    +-----------+----------------------------+-------------------------------+
    | xlarge    | 2.0 GiB (2147483648 bytes) | 1.700 GiB (1825361100 bytes)  |
    | large     | 1.5 GiB (1610612736 bytes) | 1.275 GiB (1369020825 bytes)  |
    | standard  | 1.2 GiB (1288490188 bytes) | 1.020 GiB (1095216659 bytes)  |
    +-----------+----------------------------+-------------------------------+
*/}}
{{- define "odoo.internal-resources-thread" -}}
  {{- if (eq .instance_type "xlarge") }}
LIMIT_MEMORY_SOFT: {{ .override.memory_soft | default "1825361100" | quote }}
LIMIT_MEMORY_HARD: {{ .override.memory_hard | default "2147483648" | quote }}
WORKERS: "0"
  {{- else if (eq .instance_type "large") }}
WORKERS: "0"
LIMIT_MEMORY_SOFT: {{ .override.memory_soft | default "1369020825" | quote }}
LIMIT_MEMORY_HARD: {{ .override.memory_hard | default "1610612736" | quote }}
  {{- else}}
WORKERS: "0"
LIMIT_MEMORY_SOFT: {{ .override.memory_soft | default "1095216659" | quote }}
LIMIT_MEMORY_HARD: {{ .override.memory_hard | default "1288490188" | quote }}
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
