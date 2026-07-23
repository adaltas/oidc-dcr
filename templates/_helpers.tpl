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

{{/*
  Hooks are added to ensure that:
    - The DCR related resources are created before the job is executed
    - The job is executed before the main chart is installed, upgraded or synced
    - ArgoCD does not expect the job to exist after its execution
    - The DCR related resources and the DCR job are created or executed before any other hook (if any)
    - The job is deleted if it still exists when the chart is upgraded or uninstalled
*/}}
{{- define "hooks.ressources" -}}
# ArgoCD hooks
"argocd.argoproj.io/hook": PreSync
"argocd.argoproj.io/sync-wave": "-10"
"argocd.argoproj.io/hook-delete-policy": BeforeHookCreation
# Helm hook
"helm.sh/hook": pre-install,pre-upgrade
"helm.sh/hook-weight": "-10"
"helm.sh/hook-delete-policy": before-hook-creation
{{- end -}}

{{- define "hooks.job" -}}
# ArgoCD hooks
"argocd.argoproj.io/hook": PreSync
"argocd.argoproj.io/sync-wave": "-5"
"argocd.argoproj.io/hook-delete-policy": BeforeHookCreation
# Helm hooks
"helm.sh/hook": pre-install,pre-upgrade
"helm.sh/hook-weight": "-5"
"helm.sh/hook-delete-policy": before-hook-creation
{{- end -}}
