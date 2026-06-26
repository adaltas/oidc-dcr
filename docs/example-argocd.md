# Example - ArgoCD

ArgoCD oidc integration allow the user to connect to the application using an OIDC provider

## Chart configuration

`oidc-dcr` chart is added as dependancy to the chart.

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

As the chart is multi-dependancy, the `argo-cd` and `oidc-dcr` values are nested into their corresponding parent chart name.

### ArgoCD

On ArgoCD, the permissions must be set in the value file to give specific permission to the user that will connect to the application using OIDC.

`configs.rbac` value is set with the `policy.csv` value, that allow to give permissions to a specific user or group. The `scopes` policy defines which scope the second column of the policy must match.

Read the [official ArgoCD documentation about RBAC Configuration](https://argo-cd.readthedocs.io/en/stable/operator-manual/rbac/) to learn more.

```yaml
argo-cd:
  configs:
    rbac: # RBAC configuration to give 'user@example.com' admin privileges
      policy.csv: |
        g, user@example.com, role:admin
      scopes: "[email]"
  # ...other configuration values
```

### OIDC-DCR

On OIDC-DCR, a minimal configuration is needed.

The `registration_url` must be set following the [configuration section oof README.md](https://github.com/adaltas/oidc-dcr/blob/main/README.md#configuration).

The `request` value needed to create a working application is just the `redirect_uri` that has to be set to the ArgoCD root URL followed by `/auth/callback`.

The secret name must be set to `argo-dcr` as this is the name that is used in the next section template file.

The `use_default` value needs to be set to `true` OR the `client_id` and `client_secret` values needs to be manually set to `.client_id` and `.client_secret`.

```yaml
oidc-dcr:
  registration_url: <OIDC PROVIDER REGISTRATION URL>
  request:
    client_name: "ArgoCD"
    redirect_uris:
      - "https://<APP_URL>/auth/callback"
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

A job is created in a `templates/argocd-cm-patch.yaml` file.

It is used as a middleware between the DCR job and the ArgoCD configmap as ArgoCD does not natively support `client_id` injection (and don't use an env variable that can be set).

It waits for the DCR job to finish and then patches the ArgoCD configmap with the OIDC configuration (issuer URL, client ID and secret).

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: argocd-cm-patcher
  namespace: argocd
  annotations:
    helm.sh/hook: post-install,post-upgrade
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
              echo "Client secret found: ${CLIENT_ID}"

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
