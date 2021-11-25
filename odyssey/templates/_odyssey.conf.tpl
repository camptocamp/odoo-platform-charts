{{ define "odyssey.conf.1.0.0" }}

{{- $root := . -}}

## Global configuration
{{- range $k, $v := .Values.settings.globals}}
  {{ if regexMatch "^[0-9]" ( $v | toString ) }}
   {{ $k }} {{ $v }}
  {{ else if regexMatch "^(?:yes|no)" ( $v | toString ) }}
   {{ $k }} {{ $v }}
  {{ else }}
   {{ $k }} "{{ $v }}"
  {{- end }}
{{- end }}
## Listen configuration
listen {
{{- range $k, $v := .Values.settings.listen }}
  {{ if regexMatch "^[0-9]" ( $v | toString ) }}
   {{ $k }} {{ $v }}
  {{ else if regexMatch "^(?:yes|no)" ( $v | toString ) }}
   {{ $k }} {{ $v }}
  {{ else }}
   {{ $k }} "{{ $v }}"
  {{- end }}
{{- end }}
}

{{- range $k, $v := .Values.settings.storages }}

storage "{{ $k }}" {
{{- range $subk, $subv := $v }}
  {{ $subk }} {{ $subv }}
{{- end }}
}
{{- end }}


{{- range $key, $value := .Values.settings.databases_list }}
database "{{ $value.database }}"" {
  user "{{ $value.username }}" {
  storage = {{ $value.storage }}
  password = {{ $value.password }}
{{- range $keyopt, $vopt := $value.options}}
{{ $keyopt }} {{ $vopt }}
{{- end }}
  {{- range $k, $v := $.Values.settings.databases_default_value }}
{{ $k }} {{ $v }}
{{- end }}
}
}
{{- end }}
{{ end }}

