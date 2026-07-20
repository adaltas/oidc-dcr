{{- define "secret.name" -}}
{{- .Values.secret | default .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "service_account.name" -}}
{{- .Values.security.service_account | default .Chart.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- define "role.name" -}}
{{- .Values.security.role | default .Chart.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "secret.keys" -}}
{{- if eq .Values.mapping.use_default true }}
{{- range $key, $val := .Values.mapping.default_keys }}
{{ $key }}: {{ $val | quote }}
{{- end }}
{{- end }}
{{- range $key, $val := .Values.mapping.key_mapping }}
{{ $key }}: {{ $val | quote }}
{{- end }}
{{- end -}}

{{- define "volume_mount.secret" -}}
{{- if and (not .Values.tls.insecure) (ne .Values.tls.certificate "") -}}
- name: ca-volume
  mountPath: /usr/local/share/ca-certificates/ca.crt
  subPath: ca.crt
{{- end -}}
{{- end -}}

{{- define "volume.secret" -}}
{{- if and (not .Values.tls.insecure) (ne .Values.tls.certificate "") -}}
- name: ca-volume
  secret:
    secretName: {{ $.Values.tls.certificate }}
{{- end -}}
{{- end -}}
