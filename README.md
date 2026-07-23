# Keycloak DCR registration

The `oidc-dcr` chart provides automatic client's registration with OIDC providers supporting the OpenID Connect Dynamic Client Registration (DCR) protocol (such as Keycloak). It is used to automate the registration of applications that need OIDC authentication without any manual intervention and elevated privileges.

## Architecture

The chart creates a Kubernetes Job that executes a bash script to perform the dynamic client registration. The script sends a JSON payload to the specified HTTP DCR registration endpoint and processes the response to extract relevant information (like client ID and secret). This information is then stored in a Kubernetes Secret for use by other applications.

## Chart execution

To ensure the DCR registration is executed before the main application deployment and to be able to orchestrate the execution order, the chart set [Helm](https://helm.sh/docs/topics/charts_hooks/) and [Argo CD](https://argo-cd.readthedocs.io/en/stable/user-guide/sync-waves/) orchestrations hooks to `pre-install`/`pre-upgrade` for Helm and `PreSync` for Argo CD.

All the DCR-related resources (ConfigMap, Service, ServiceAccount, Role, RoleBinding) are created in first. Then, the Job is executed using all the ressources previously created. The Job still have a negative hook-weight ensuring any other `pre-install`/`pre-upgrade` or `PreSync` job from the main chart is executed after.

## Example

- [Headlamp integration](./docs/example-headlamp.md)
- [Argo CD integration](./docs/example-argocd.md)

## Roadmap

- Validate/enrich the configuration
- Respect Helm documentation best-practices
- Helm test best practices
- Fix error "Resource not found in cluster" in Argo CD
- Externalise the script to an external file
- Any other Helm best practices

## Configuration

- `enabled`  
  Placeholder property to use when defining this chart as a depencency in an umbrela chart.

- `image`  
  The Alpine-based Docker image used to run the registration script. It must include `curl` and `jq`. (Default: `alpine:latest`)

- `mapping`
  - `use_default`  
    Controls the key generation for the output object. If set to `true`, all alias keys defined in the `default_keys` section will be injected into the secret (default option). If `false`, only custom keys defined manually will be included. It is possible to set custom keys while keeping the default ones by setting `use_default` to `true`. In this case, the custom keys will overwrite the default ones if they share the same name.
  - `key_mapping`  
    Defines custom mappings between the DCR response fields and the keys in the Kubernetes Secret. The keys represent the desired field names in the output secret, while the values specify how to extract or define the corresponding values from the DCR response. Values starting with a dot (`.`) are **Dynamic Fields**. They are interpreted as `jq` filters applied directly to the DCR JSON response (e.g., `.client_id` ==> `jq | .client_id`). Values without a leading dot are **Static Fields** and are written directly as hard-coded strings.
  - `default_keys`  
    A pre-defined set of common mappings in different naming conventions to provide a "ready to use" configuration for the most common use cases.

- `registration_url`  
  The OIDC provider registration URL used to process the dynamic registration.

- `ttl_seconds`  
  Time-to-live duration (in seconds) to preserve the Kubernetes Job logs after execution for debugging purposes. `0` disables automatic deletion or relies on cluster-level defaults. (Default: `60`)

- `request`  
  The JSON payload sent to the OIDC identity provider during registration is defined under the `request` section. It supports all the standard fields defined in the OpenID Connect Dynamic Client Registration specification, as well as some Keycloak-specific extensions. The most common fields are:
  - `application_type`  
    Kind of the application. Supported values are `native` or `web`. (Default: `"web"`)
  - `client_name`  
    The display name of the OIDC client shown on login and consent screens. (Default: `""`)
  - `logo_uri`  
    URL pointing to the logo of the client application. (Default: `""`)
  - `grant_types`  
    OAuth 2.0 grant types that the client restricts itself to using. (Default: `["authorization_code", "client_credentials"]`)
  - `redirect_uris`  
    List of allowed callback URLs where the identity provider can redirect users after authentication. (Default: `[]`)
  - `response_types`  
    List of expected OAuth 2.0 response type values (e.g., `code`). (Default: `[]`)
  - `client_uri`  
    URL of the home page of the client application. (Default: `""`)
  - `token_endpoint_auth_method`  
    Authentication method used by the client at the token endpoint. Supported values include `client_secret_basic`, `client_secret_post`, `client_secret_jwt`, `private_key_jwt`, and `none`. Using none creates a public client (client without secret) (Default: `client_secret_basic`)

- `tls`
  Use of TLS in client creation via the DCR API.
  - `insecure`
    Use the `insecure` option of the `curl` command. Supported values are `true` or `false`. (Default: `false`)
  - `certificate`
    Mount a secret into DCR jobs. Value needs to match the name of an accessible secret.

- `secret`  
  Control the name for the created Kubernetes Secret. If left empty, the Helm chart name is used.

- `security`  
  Names of the Kubernetes ServiceAccount and RBAC role used to execute the Job and grant it permissions to create the Secret.
  - `security.service_account`  
    Name of the Kubernetes ServiceAccount used to execute the job. (Default: `<Chart name>`)
  - `security.role`  
    Name of the RBAC role associated with the ServiceAccount to grant Secret creation permissions. (Default: `<Chart name>`)

### Data Mapping

The `mapping` section defines how the response from the OIDC provider is transformed into the data stored in the Kubernetes Secret. It provides a flexible mechanism to map response fields of the DCR request into the output Kubernetes secret.

The available fields in the DCR response are the following:

- **IDENTIFIERS & SECRETS**
  - `.client_id`: Unique generated identifier (UUID). Required for OIDC_CLIENT_ID.
  - `.client_secret`: The client's password. Required for OIDC_CLIENT_SECRET.
  - `.client_id_issued_at`: Unix timestamp of when the client was created.
  - `.client_secret_expires_at`: 0 means the secret never expires. Note, the client secret rotation is currently [not supported by Keycloak](https://github.com/keycloak/keycloak/discussions/9156).
- **DYNAMIC MANAGEMENT**
  - `.registration_client_uri`: Unique URL to read or modify this specific client.
  - `.registration_access_token`: Security token required to access the registration_client_uri.

On top of those standard fields, the DCR response also includes keykloak-specific fields that can be mapped for more advanced use cases:

- **FLOW CONFIGURATION**
  - `.redirect_uris`  
    List of allowed callback URLs after authentication.
  - `.post_logout_redirect_uris`  
    List of allowed URLs to redirect to after logging out.
  - `.grant_types`: List of Authorized OAuth2 flows (e.g., authorization_code, client_credentials).
  - `.response_types`  
    List of expected response type (e.g., code).
  - `.token_endpoint_auth_method`  
    Auth method for the token endpoint (client_secret_basic).
- **SCOPES & IDENTITY**
  - `.scope`
    List of granted permissions (e.g., openid, offline_access, microprofile-jwt).
  - `.subject_type`
    "public" (same user ID across all clients) or "pairwise".
  - `.client_name`  
    The display name shown on the login/consent screen.
- **ADVANCED SECURITY**
  - `.tls_client_certificate_bound_access_tokens`  
    Token binding to TLS certificates (mTLS).
  - `.dpop_bound_access_tokens`  
    Use of DPoP to bind tokens to the client.
  - `.backchannel_logout_session_required`  
    Whether Keycloak sends logout notifications in the background.
  - `.frontchannel_logout_session_required`  
    Whether logout notifications are sent via the browser.
  - `.require_pushed_authorization_requests`  
    Whether PAR (RFC 9126) is mandatory.
  - `.request_uris`  
    Pre-registered list of URLs for Request Objects.

> [!NOTE]
> `registration_client_uri` and `registration_access_token` fields are mapped even if `use_default` is set to `false` to allow the script to automatically detect the registration of the client in case the job is restarted.

## Keycloak Notes

Some DCR fields are not supported by Keybase (e.g., `contacts`). Those fields can still be included in the `request` section but will be ignored by Keycloak and won't be present in the response.
