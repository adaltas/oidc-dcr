#!/usr/bin/env sh

# Waits for the OIDC provider before the registration: polls the OIDC
# discovery URL every 5 seconds, for up to WAIT_TTL_SECONDS seconds, until it
# answers with JSON. The registration script does not check the HTTP status of
# its request: while the provider starts, it would read an error page (e.g. the
# 503 of an ingress) as a response and fail on it.

# The dependencies (curl, jq) are provided by the image

# The custom CA certificate is passed to curl directly, when it is mounted (it
# is not with tls.insecure)
CA_FILE=/usr/local/share/ca-certificates/ca.crt
if [ -f "$CA_FILE" ]; then
  CURL_OPTION="$CURL_OPTION --cacert $CA_FILE"
fi

deadline=$(($(date +%s) + WAIT_TTL_SECONDS))
# shellcheck disable=SC2086
until curl $CURL_OPTION -f "$OIDC_DISCOVERY_URL" | jq -e .issuer >/dev/null 2>&1; do
  if [ "$(date +%s)" -ge "$deadline" ]; then
    echo "ERROR: $OIDC_DISCOVERY_URL did not answer in $WAIT_TTL_SECONDS seconds"
    exit 1
  fi
  echo "INFO: waiting for the OIDC provider ($OIDC_DISCOVERY_URL)"
  sleep 5
done
echo "INFO: OIDC provider ready"
