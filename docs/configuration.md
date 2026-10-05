# Configuration

The Helm chart is configured with the following properties.

- `enabled`  
  Placeholder property to use when defining this chart as a depencency in an umbrela chart.

- `image`  
  The image used to run the registration script. It embeds `curl`, `jq` and `kubectl`, nothing is downloaded when the job starts. See [Airgapped clusters](./airgap.md).
  - `registry`  
    Registry hosting the image. Leave empty to use the repository name only. (Default: `quay.io`)
  - `repository`  
    Repository of the image. A custom image must provide `sh`, `curl`, `jq` and `kubectl`. (Default: `adaltas/oidc-dcr-job`)
  - `tag`  
    Tag of the image. (Default: the chart version)
  - `pull_policy`  
    Kubernetes image pull policy, `Always`, `IfNotPresent` or `Never`. (Default: `IfNotPresent`)
  - `pull_secrets`  
    List of secret names used to pull the image from a private registry. (Default: `[]`)

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

- `backoff_limit`  
  Number of retries of the Job before it is marked as failed. Raise it when the OIDC provider may refuse the first registrations, for example while its configuration is being applied. (Default: `1`)

- `wait_for_provider`  
  Waits for the OIDC provider before registering the client.
  - `discovery_url`  
    OIDC discovery URL of the provider, for example `https://keycloak.example.com/realms/my-realm/.well-known/openid-configuration`. When set, the Job gets a `wait-oidc-provider` init container (same image, pull policy, `curl` options and volume mounts, the CA certificate included, as the registration container) that polls the URL every 5 seconds, for up to 10 minutes, until it answers with JSON. Use it when the chart is installed along with the provider: the registration script does not check the HTTP status of its request and would fail on the error page of a provider that is still starting. (Default: `""`, no init container)

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
  - `scope`
    Space-separated list of OAuth 2.0 scopes that the client restricts itself to using. (when not specified, the provider may assign all the default client scopes)

- `tls`
  Use of TLS in client creation via the DCR API.
  - `insecure`
    Use the `insecure` option of the `curl` command. Supported values are `true` or `false`. (Default: `false`)
  - `certificate`
    Mount a secret into DCR jobs. Value needs to match the name of an accessible secret.

- `secret`  
  Control the name for the created Kubernetes Secret. If left empty, the Helm chart name is used.

- `fullname_override`  
  Name of the Job, its ConfigMap and its RoleBinding, and prefix of the headless Service (`<name>-headless`, selecting the Job's pod). Every registration of a namespace needs its own name, for example two releases of the chart, or two clients registered by the same umbrella chart. (Default: `dcr`)

- `common_labels`  
  Labels added to every object of the chart and to the pod of the Job, for example `app.kubernetes.io/instance` to group the objects with the application registering the client. (Default: `{}`)

- `security`  
  Names of the Kubernetes ServiceAccount and RBAC role used to execute the Job and grant it permissions to create the Secret.
  - `security.service_account`  
    Name of the Kubernetes ServiceAccount used to execute the job. (Default: `fullname_override`, then `<Chart name>`)
  - `security.role`  
    Name of the RBAC role associated with the ServiceAccount to grant Secret creation permissions. (Default: `fullname_override`, then `<Chart name>`)

## Keycloak Notes

Some DCR fields are not supported by Keybase (e.g., `contacts`). Those fields can still be included in the `request` section but will be ignored by Keycloak and won't be present in the response.
