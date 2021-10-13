{{ define "odyssey.conf.1.0.0" }}

{{- $root := . -}}

## Global configuration
{{- range $k, $v := .Values.settings.globals}}
{{ $k }} = "{{ $v }}"
{{- end }}
## Listen configuration
listen {
{{- range $k, $v := .Values.settings.listen }}
{{ $k }} = "{{ $v }}"
{{- end }}
}

{{- range $k, $v := .Values.settings.storages }}

storage {{ $k }} {
{{- range $subk, $subv := $v }}
{{ $subk }} = "{{ $subv }}"
{{- end }}
}
{{- end }}


{{- range $k, $v := .Values.settings.databases }}
database {{ $k }} {
{{- range $subdbk, $subdbv := $v }}
user {{ $subdbk }} {
{{- range $subuserk, $subuserv := $subdbv }}
{{ $subuserk }} = "{{ $subuserv }}"
{{- end }}
}
{{- end }}
}
{{- end }}

{{- range $key, $value := .Values.settings.databases_list }}
database {{ $value.database }} {
user {{ $value.username }} {
password = "{{ $value.password }}"
{{- range $k, $v := .Values.settings.databases_default_value }}
{{ $k }} = "{{ $v }}"
{{- end }}
}
}
{{- end }}



{{ end }}

