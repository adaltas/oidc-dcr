# Headlamp Example

The official Headlamp chart is configured to OIDC information from an external secret stored in the same namespace. The properties stored in the secret are converted into environment variables. The name of the properties are not configured. The OIDC DCR chart is configured to write the expected properties.

The umbrella chart `Chart.yaml` declares keycloack and the OIDC DCR dependencies.

```yaml
apiVersion: v2
name: headlamp
version: 1.0.0
dependencies:
  - name: oidc-dcr
    version: 0.1.0
    repository: file://../oidc-dcr
  - name: headlamp
    version: 0.30.1
    repository: https://kubernetes-sigs.github.io/headlamp
```

The values for a Headlamp deployment with Keycloak as OIDC provider is defined.

```yaml
headlamp:
  #...
  config:
    oidc:
      secret:
        create: false
        name: dcr
      externalSecret:
        enabled: true
        name: dcr
  #...
oidc-dcr:
  registration_url: http://keycloak-http.keycloak.svc:80/auth/realms/adaltas/clients-registrations/openid-connect/
  request:
    application_type: native
    client_name: Headlamp
    redirect_uris:
      - "https://headlamp.admin.k8s.demo/oidc-callback"
      - "http://localhost:18080/*"
  secret: headlamp-secret
  mapping:
    use_default: false
    key_mapping:
      OIDC_CLIENT_ID: ".client_id"
      OIDC_CLIENT_SECRET: ".client_secret"
      OIDC_ISSUER_URL: "https://keycloak.admin.k8s.demo/auth/realms/adaltas"
      OIDC_SCOPES: "openid email profile"
```

The corresponding Kubernetes Secret is created by the Job.

```json
{
  "apiVersion": "v1",
  "data": {
    "OIDC_CLIENT_ID": "<base64-encoded clientId>",
    "OIDC_CLIENT_SECRET": "<base64-encoded clientSecret>",
    "OIDC_ISSUER_URL": "<base64-encoded issuer URL>",
    "OIDC_SCOPES": "<base64-encoded scopes>",
    "registration_access_token": "<base64-encoded registration access token>",
    "registration_client_uri": "<base64-encoded registration client URI>"
  },
  "kind": "Secret",
  "metadata": {
    "creationTimestamp": "<timestamp>",
    "name": "headlamp-secret",
    "namespace": "headlamp",
    "resourceVersion": "<resource version>",
    "uid": "<UUID>"
  },
  "type": "Opaque"
}
```

The clear text data is then retrieved using `kubectl get secrets -n <namespace> <secret-name> -o json | jq '.data | map_values(@base64d)'`:

```json
{
  "OIDC_CLIENT_ID": "<clientId>",
  "OIDC_CLIENT_SECRET": "<clientSecret>",
  "OIDC_ISSUER_URL": "http://keycloak-http.keycloak.svc:80/auth/realms/adaltas",
  "OIDC_SCOPES": "openid email profile",
  "registration_access_token": "<registration access token>",
  "registration_client_uri": "http://keycloak-http.keycloak.svc/auth/realms/adaltas/clients-registrations/openid-connect/<clientId>"
}
```
