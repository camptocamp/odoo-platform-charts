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

{{ end }}
