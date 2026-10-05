{{- define "secret.name" -}}
{{- .Values.secret | default .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "image" -}}
{{- $name := printf "%s:%s" .Values.image.repository (.Values.image.tag | default .Chart.Version) -}}
{{- if .Values.image.registry -}}
{{- printf "%s/%s" .Values.image.registry $name -}}
{{- else -}}
{{- $name -}}
{{- end -}}
{{- end -}}

{{/*
  Name of the Job, its ConfigMap and its RoleBinding, default "dcr": two
  registrations in one namespace need distinct names (fullname_override).
*/}}
{{- define "dcr.name" -}}
{{- .Values.fullname_override | default "dcr" | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- define "dcr.headless" -}}
{{- printf "%s-headless" (include "dcr.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "service_account.name" -}}
{{- .Values.security.service_account | default .Values.fullname_override | default .Chart.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- define "role.name" -}}
{{- .Values.security.role | default .Values.fullname_override | default .Chart.Name | trunc 63 | trimSuffix "-" -}}
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

{{/*
  Volume mounts of the job containers: the registration script, and the CA
  certificate when one is configured.
*/}}
{{- define "volume_mounts" -}}
- name: dcr-volume
  mountPath: /mnt/dcr
{{- with include "volume_mount.secret" . }}
{{ . }}
{{- end }}
{{- end -}}

{{- define "curl.option" -}}
{{- if .Values.tls.insecure -}}-sk{{- else -}}-s{{- end -}}
{{- end -}}

{{/*
  Script of the wait-oidc-provider init container: polls the OIDC discovery URL
  every 5 seconds, for up to WAIT_TTL_SECONDS seconds, until it answers with
  JSON. The registration script does not check the HTTP status of its request:
  while the provider starts, it would read an error page (e.g. the 503 of an
  ingress) as a response and fail on it.
*/}}
{{- define "wait.script" -}}
if [ -f /usr/local/share/ca-certificates/ca.crt ]; then CURL_OPTION="$CURL_OPTION --cacert /usr/local/share/ca-certificates/ca.crt"; fi
deadline=$(($(date +%s) + WAIT_TTL_SECONDS))
until curl $CURL_OPTION -f "$OIDC_DISCOVERY_URL" | jq -e .issuer >/dev/null 2>&1; do
  if [ "$(date +%s)" -ge "$deadline" ]; then echo "ERROR: $OIDC_DISCOVERY_URL did not answer in $WAIT_TTL_SECONDS seconds"; exit 1; fi
  echo "INFO: waiting for the OIDC provider ($OIDC_DISCOVERY_URL)"
  sleep 5
done
echo "INFO: OIDC provider ready"
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
