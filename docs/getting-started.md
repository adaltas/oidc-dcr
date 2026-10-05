# Getting started

## Prerequisites

- **Helm 3** (`helm version`)
- A running **Kubernetes cluster** with `kubectl` access
- An **OIDC provider** that supports [Dynamic Client Registration](https://openid.net/specs/openid-connect-registration-1_0.html) (e.g. Keycloak)

## How it works

`oidc-dcr` runs as a Helm pre-install/pre-upgrade hook Job:

1. It calls the OIDC provider's DCR endpoint with your registration payload.
2. It stores the response (client ID, client secret, and any other fields you configure) into a Kubernetes Secret.
3. Your application chart reads that Secret — typically as environment variables — to configure its OIDC client.

## Finding the latest version

The chart is published as an OCI image. Retrieve the latest version with `helm show chart`:

```bash
helm show chart oci://quay.io/adaltas/oidc-dcr \
| yq '{ "name": .name, "version": .version, "description": .description }'
#> name: oidc-dcr
#> version: 0.3.0
#> description: Keycloak Dynamic Client Registration (DCR)
```

## Adding oidc-dcr as a dependency

OIDC DCR is declared as a dependecy in your umbrella chart's `Chart.yaml`. The optional `condition` field lets you toggle it off without removing the dependency. It equals `true` by default.

```yaml
#...
dependencies:
  - condition: oidc-dcr.enabled
    name: oidc-dcr
    repository: oci://quay.io/adaltas
    version: ">=0.3.0"
  - name: headlamp
    version: 0.30.1
    repository: https://kubernetes-sigs.github.io/headlamp
#...
```

The dependency is then configured in the `value.yaml` file. The enabled property is used to conditionnally activate and download the dependency.

```yaml
oidc-dcr:
  enabled: true
  #... Additionnal oidc-dcr properties
```

Then run `helm dependency update` to download the chart.

## Mapping DCR response fields to Secret keys

The `mapping.keyMapping` option controls what ends up in the Kubernetes Secret:

- A value starting with `.` is a **jq filter** applied to the DCR JSON response (e.g. `.client_id` extracts the registered client ID).
- Any other value is written **as-is** — useful for static configuration such as the issuer URL or scope list.

Set `mapping.useDefault: false` to write only the keys you define explicitly, rather than the built-in set of aliases.

```yaml
oidc-dcr:
  # ...
  mapping:
    useDefault: false
    keyMapping:
      OIDC_CLIENT_ID: ".client_id"
      OIDC_CLIENT_SECRET: ".client_secret"
      OIDC_ISSUER_URL: "https://keycloak.admin.k8s.demo/auth/realms/adaltas"
      OIDC_SCOPES: "openid email profile"
```

See [Data Mapping](./data-mapping.md) for the full list of available DCR response fields.

## Headlamp integration example

This example registers a Headlamp OIDC client with Keycloak and configures Headlamp to read the resulting Secret.

`Chart.yaml`:

```yaml
apiVersion: v2
name: headlamp
version: 1.0.0
dependencies:
  - name: oidc-dcr
    version: ">=0.3.0"
    repository: oci://quay.io/adaltas
    condition: oidc-dcr.enabled
  - name: headlamp
    version: 0.30.1
    repository: https://kubernetes-sigs.github.io/headlamp
```

`values.yaml`:

```yaml
oidc-dcr:
  enabled: true
  registrationUrl: http://keycloak-http.keycloak.svc:80/auth/realms/adaltas/clients-registrations/openid-connect/
  request:
    application_type: native
    client_name: Headlamp
    redirect_uris:
      - "https://headlamp.admin.k8s.demo/oidc-callback"
      - "http://localhost:18080/*"
  secret: headlamp-secret
  mapping:
    useDefault: false
    keyMapping:
      OIDC_CLIENT_ID: ".client_id"
      OIDC_CLIENT_SECRET: ".client_secret"
      OIDC_ISSUER_URL: "https://keycloak.admin.k8s.demo/auth/realms/adaltas"
      OIDC_SCOPES: "openid email profile"

headlamp:
  config:
    oidc:
      secret:
        create: false
        name: headlamp-secret
      externalSecret:
        enabled: true
        name: headlamp-secret
```

OIDC DCR creates the `headlamp-secret` Secret before Headlamp deploys. Headlamp then reads that Secret directly for its OIDC configuration.

## Next steps

- [Configuration reference](./configuration.md): all available `values.yaml` options.
- [Data mapping](./data-mapping.md): DCR response fields and advanced mapping syntax.
- [Headlamp example](./example-headlamp.md): full end-to-end walkthrough.
- [Argo CD example](./example-argocd.md): deploying with Argo CD sync waves.
