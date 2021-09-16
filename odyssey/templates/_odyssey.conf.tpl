{{ define "odyssey.conf.1.0.0" }}

{{- $root := . -}}

## Global configuration
{{- range $k, $v := .Values.setting.global }}
{{ $k }} = {{ $v }}
{{-end}}
## Listen configuration
listen {
{{- range $k, $v := .Values.setting.listen }}
{{ $k }} = {{ $v }}
{{-end}}
}

{{- range $k, $v := .Values.setting.storages }}

storage {{ $k }} {
{{- range $subk, $subv := $v }}
{{ $subk }} = {{ $subv }}
{{-end}}
}
{{-end}}

{{- range $k, $v := .Values.setting.databases }}

database {{ $k }} {
{{- range $subk, $subv := $v }}
{{ $subk }} = {{ $subv }}
{{-end}}
}
{{-end}}
