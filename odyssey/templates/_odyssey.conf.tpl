{{ define "odyssey.conf.1.0.0" }}

{{- $root := . -}}

## Global configuration
{{- range $k, $v := .Values.settings.globals}}
  {{ if regexMatch "^[0-9]+$" ( $v | toString ) }}
   {{ $k }} {{ $v }}
  {{ else if regexMatch "^(?:yes|no)" ( $v | toString ) }}
   {{ $k }} {{ $v }}
  {{ else }}
   {{ $k }} "{{ $v }}"
  {{- end }}
{{- end }}
## Listen configuration
listen
{
{{- range $k, $v := .Values.settings.listen }}
  {{ if regexMatch "^[0-9]+$" ( $v | toString ) }}
   {{ $k }} {{ $v }}
  {{ else if regexMatch "^(?:yes|no)" ( $v | toString ) }}
   {{ $k }} {{ $v }}
  {{ else }}
   {{ $k }} "{{ $v }}"
  {{- end }}
{{- end }}
}

{{- range $k, $v := .Values.settings.storages }}

storage "{{ $k }}"
{
{{- range $subk, $subv := $v }}
  {{ if regexMatch "^[0-9]+$" ( $subv | toString ) }}
   {{ $subk }} {{ $subv }}
  {{ else if regexMatch "^(?:yes|no)" ( $subv | toString ) }}
   {{ $subk }} {{ $subv }}
  {{ else }}
   {{ $subk }} "{{ $subv }}"
  {{- end }}

{{- end }}
}
{{- end }}


{{- range $key, $value := .Values.settings.databases_list }}
database "{{ $value.database }}" {
user "{{ $value.database }}" {
{{- range $key_db, $value_db := $value }}
  {{ if regexMatch "^[0-9]+$" ( $value_db | toString ) }}
   {{ $key_db }} {{ $value_db }}
  {{ else if regexMatch "^(?:yes|no)" ( $value_db | toString ) }}
   {{ $key_db }} {{ $value_db }}
  {{ else }}
   {{ $key_db }} "{{ $value_db }}"
  {{- end }}
{{- end }}
  {{- range $k, $v := $.Values.settings.databases_default_value }}
  {{ if regexMatch "^[0-9]+$" ( $v | toString ) }}
   {{ $k }} {{ $v }}
  {{ else if regexMatch "^(?:yes|no)" ( $v | toString ) }}
   {{ $k }} {{ $v }}
  {{ else }}
   {{ $k }} "{{ $v }}"
  {{- end }}

{{- end }}
}
}
{{- end }}
{{ end }}
