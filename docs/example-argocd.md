# Example - Argo CD

Argo CD OIDC integration allows users to connect to the application using an Argo CD OpenID Connect (OIDC) identity provider. This process is automated using the OIDC-DCR chart.

An `argocd-cm-patch` job is introduced to read the generated client ID and insert it into the Argo CD's ConfigMap as Argo CD does not natively support injecting a ClientID directly from an external secret or environment variable. Because the DCR job has a Helm hook weight of -5, it executes with higher priority. Therefore, when the patch job runs, the Kubernetes secret is already available, allowing it to extract the `client_id` and `client_secret` and inject them directly into the Argo CD ConfigMap.

## Chart configuration

`oidc-dcr` chart is added as a dependency to the main chart alongside Argo CD.

```yaml
apiVersion: v2
name: argo-cd
version: 1.0.0
dependencies:
  - name: argo-cd
    version: 9.2.3
    repository: https://argoproj.github.io/argo-helm
  - name: oidc-dcr # Add oidc-dcr
    version: 0.1.0
    repository: "file://../oidc-dcr"
```

## Values file

Because this is a multi-dependency chart, the configuration keys for both Argo CD and OIDC-DCR must be nested under their respective parent chart names.

### Argo CD configuration (RBAC)

To allow users authenticating via OIDC to interact with the application, appropriate permissions must be defined in the values file.

The `policy.csv` key, under `configs.rbac`, defines the access policies. The scopes setting specifies which token claim (such as [email]) will be evaluated against the second column of the RBAC policy.

Read the [official Argo CD documentation about RBAC Configuration](https://argo-cd.readthedocs.io/en/stable/operator-manual/rbac/) to learn more.

```yaml
argo-cd:
  configs:
    rbac: # RBAC configuration to give 'user@example.com' admin privileges
      policy.csv: |
        g, user@example.com, role:admin
      scopes: "[email]"
  # ...other configuration values
```

### OIDC-DCR configuration

A minimal configuration is required for the OIDC-DCR component to handle dynamic client registration:

- The `registration_url` value must be set to the dynamic client registration URL provided by your OIDC identity provider.
- The `request` key must be filled with the `redirect_uris` that indicates the Argo CD callback url (see example below).
- The `secret` must be set to `argo-dcr` to match the target name used by the patch job in the next section.
- The `use_default` value needs to be set to `true` OR the `client_id` and `client_secret` values needs to be manually set to `.client_id` and `.client_secret`.

```yaml
oidc-dcr:
  registration_url: <OIDC PROVIDER REGISTRATION URL>
  request:
    client_name: "ArgoCD"
    redirect_uris:
      - "https://<ARGOCD_URL>/auth/callback"
  secret: "argo-dcr"
  mapping:
    # First choice (easier)
    use_default: true
    # ---- OR ----
    # Second choice (cleaner secret)
    use_default: false
    key_mapping:
      client_id: .client_id
      client_secret: .client_secret
```

## Patch job

Since Argo CD does not natively support dynamic `client_id` injection via environment variables or external secrets, a Kubernetes Job is defined in `templates/argocd-cm-patch.yaml` and acts as a middleware between the DCR job and the Argo CD configmap.

This job executes post-installation or post-upgrade. It waits for the `oidc-dcr` job to generate the required secret, extracts the generated Client ID and Client Secret, and directly patches the `argocd-cm` ConfigMap.

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: argocd-cm-patcher
  namespace: argocd
  annotations:
    # The job is executed right after the Helm install/upgrade command (but after the DCR job, which has a negative hook weight giving it a higher priority).
    helm.sh/hook: post-install,post-upgrade
    # Ensure that Helm correctly handles the job deletion after execution, or replaces it when the job is re-created in case of error.
    helm.sh/hook-delete-policy: before-hook-creation,hook-succeeded
spec:
  template:
    spec:
      serviceAccountName: argocd-server
      restartPolicy: OnFailure
      containers:
        - name: patcher
          image: bitnami/kubectl:latest # Use a lightweight image with kubectl installed from Bitnami
          command:
            - /bin/bash
            - -c
            - |
              # Wait for the DCR job to complete
              echo "Waiting for secret argo-dcr generation..."
              until kubectl get secret argo-dcr -n argocd &>/dev/null; do
                sleep 2
              done

              # Retrieve the client ID and secret from the generated secret argo-dcr
              CLIENT_ID=$(kubectl get secret argo-dcr -n argocd -o jsonpath='{.data.client_id}' | base64 -d)
              CLIENT_SECRET=$(kubectl get secret argo-dcr -n argocd -o jsonpath='{.data.client_secret}' | base64 -d)

              # Check if CLIENT_ID and CLIENT_SECRET is empty and exit with an error message if it is
              if [ -z "$CLIENT_ID" ]; then
                echo "Error: client_id not found in argo-dcr"
                exit 1
              fi
              if [ -z "$CLIENT_SECRET" ]; then
                echo "Error: client_secret not found in argo-dcr"
                exit 1
              fi

              echo "Client ID found: ${CLIENT_ID}"
              echo "Client secret retrieved successfully."

              # Patch the ArgoCD configmap with the OIDC configuration
              kubectl patch configmap argocd-cm -n argocd --type merge -p "$(cat <<EOF
              {
                "data": {
                  "oidc.config": "name: Keycloak\nissuer: https://keycloak.admin.k8s.demo/auth/realms/adaltas\nclientID: ${CLIENT_ID}\nclientSecret: ${CLIENT_SECRET}\nrequestedScopes: [\"openid\", \"profile\", \"email\"]"
                }
              }
              EOF
              )"

              echo "Configmap argocd-cm patched successfully!"
```
