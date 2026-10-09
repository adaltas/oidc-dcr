#!/usr/bin/env sh

# The dependencies (curl, jq, kubectl) are provided by the image

# The custom CA certificate is passed to curl directly, no need to update the
# system trust store
CA_FILE=/usr/local/share/ca-certificates/ca.crt
if [ -n "$TLS_CERTIFICATE" ]; then
  CURL_OPTION="$CURL_OPTION --cacert $CA_FILE"
fi

# Reverse DNS wait
# Providers with a trusted hosts policy reverse-resolve the IP of the caller.
# The record of the pod IP, published by the headless service, appears after
# the pod starts.
# TODO: a failed lookup may be cached by the DNS server (negative cache) and
# still be served to the provider after the record appears. Add a pause once
# the issue is reproduced.
if [ "${DNS_WAIT_TTL_SECONDS:-0}" -gt 0 ] && [ -n "$POD_IP" ]; then
  deadline=$(($(date +%s) + DNS_WAIT_TTL_SECONDS))
  until nslookup "$POD_IP" 2>/dev/null | grep -q 'name = ' \
    || [ "$(date +%s)" -ge "$deadline" ]; do
    sleep 1
  done
  if [ "$(date +%s)" -ge "$deadline" ]; then
    >&2 echo "ERROR: no reverse DNS record for $POD_IP after $DNS_WAIT_TTL_SECONDS seconds"
    exit 2
  fi
  echo "INFO: reverse DNS record found for $POD_IP"
fi

# Current registration detection
secret=$(kubectl get secret "$SECRET_NAME" -o json 2>/dev/null)
if [ -n "$secret" ] >/dev/null; then
  response=$(
    # shellcheck disable=SC2086
    curl $CURL_OPTION \
      -H "Content-Type:application/json" \
      -H "Authorization: Bearer $(
        echo "$secret" | jq -r '.data.registration_access_token | @base64d'
      )" \
      "$(echo "$secret" | jq -r '.data.registration_client_uri | @base64d')"
  )
  if [ $? = "0" ] && ! echo "$response" | jq -er '.error'; then
    echo 'INFO: Client is already registered in the OIDC provider.'
    # The registration access token is still unchanged because no change was made to the client
    exit 0
  fi
  echo 'INFO: Secret information for client exists but is not valid.'
fi

# DCR registration
echo 'INFO: DCR registration'
echo 'INFO: Request body'
echo "$REQUEST" | jq . # Log the request for debugging purposes
# shellcheck disable=SC2086
response=$(curl $CURL_OPTION \
  -H "Content-Type:application/json" \
  -d "$REQUEST" \
  "$DCR_REGISTRATION_URL")
[ $? != "0" ] && {
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
if ! echo "$manifest" | kubectl apply --token="$token" -f -; then
  >&2 echo "ERROR: Secret creation failed with exit code $?."
  exit 1
fi

# Success
echo 'INFO: Client is now registered in the OIDC provider.'
