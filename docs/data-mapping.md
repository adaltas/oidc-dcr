# Data Mapping

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
