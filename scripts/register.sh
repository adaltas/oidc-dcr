#!/usr/bin/env sh

# Dependencies installation
apk add curl jq bind-tools kubectl
if [[ -n $TLS_CERTIFICATE ]]; then
apk add ca-certificates
update-ca-certificates 
fi
# Current registration detection
secret=$(kubectl get secret "$SECRET_NAME" -o json 2>/dev/null)
if [[ -n "$secret" ]] >/dev/null; then
  response=$(
    curl "$CURL_OPTION" \
      -H "Content-Type:application/json" \
      -H "Authorization: Bearer $(
        echo "$secret" | jq -r '.data.registration_access_token | @base64d'
      )" \
      $(echo "$secret" | jq -r '.data.registration_client_uri | @base64d')
  )
  if [[ $? == "0" ]] && ! echo "$response" | jq -er '.error'; then
    echo 'INFO: Client is already registered in the OIDC provider.'
    # The registration access token is still unchanged because no change was made to the client
    exit 0
  fi
  echo 'INFO: Secret information for client exists but is not valid.'
fi
echo 'INFO: DCR registration'
# DCR registration
echo 'INFO: Request body'
echo "$REQUEST" | jq . # Log the request for debugging purposes
response=$(curl "$CURL_OPTION" \
  -H "Content-Type:application/json" \
  -d "$REQUEST" \
  "$DCR_REGISTRATION_URL")

[[ $? != "0" ]] && {
  >&2 echo "ERROR: Client registration HTTP request failed with exit code $?."
  exit 1
}
error=$(echo "$response" | jq -er '.error') && { echo "ERROR: DCR request return error \"$error\""; exit 1; }
echo 'INFO: Client registration successful.'
echo 'INFO: DCR response'
echo "$response" | jq . # Log the response for debugging purposes
echo 'INFO: Secret information storage'
# Secret information storage
# The manifest is generated using the secret_keys variable
# The values that start with a dot will extract the value from the DCR response, otherwise it will use the hard-coded value
manifest=$(
  echo "$response" \
  | jq -r --arg name "$SECRET_NAME" --argjson keys "$SECRET_KEYS" '
    (to_entries | map({ (.key): .value }) | add) as $oidc
    | {
        apiVersion: "v1",
        kind: "Secret",
        metadata: { name: $name },
        type: "Opaque",
        data: ($keys | map_values($oidc[. | sub("^\\."; "")] // .)) | map_values(@base64)
    }
  '
)
token=$(cat /run/secrets/kubernetes.io/serviceaccount/token)
echo "$manifest" | kubectl apply --token="$token" -f -
[[ $? != "0" ]] && {
  >&2 echo "ERROR: Secret creation failed with exit code $?."
  exit 1
}
# Success
echo 'INFO: Client is now registered in the OIDC provider.'
