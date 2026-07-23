# Configuration

The Helm chart is configured with the following properties.

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

## Keycloak Notes

Some DCR fields are not supported by Keybase (e.g., `contacts`). Those fields can still be included in the `request` section but will be ignored by Keycloak and won't be present in the response.
