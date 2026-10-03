# Airgapped clusters

The registration job runs the [`quay.io/adaltas/oidc-dcr-job`](https://quay.io/repository/adaltas/oidc-dcr-job) image which embeds all the script dependencies (`curl`, `jq` and `kubectl`). Nothing is downloaded when the job starts, the only external resource is the image itself. Its tag matches the chart version.

## Mirroring the image

Copy the image matching the chart version in the private registry of the cluster, for example with [`skopeo`](https://github.com/containers/skopeo):

```bash
VERSION=0.4.0
skopeo copy --all \
  docker://quay.io/adaltas/oidc-dcr-job:$VERSION \
  docker://registry.internal/adaltas/oidc-dcr-job:$VERSION
```

Then override the registry in the chart values, along with a pull secret if the registry requires authentication:

```yaml
oidc-dcr:
  image:
    registry: registry.internal
    pull_secrets:
      - registry-credentials
```

The chart itself is published as an OCI artifact and can be mirrored the same way:

```bash
skopeo copy \
  docker://quay.io/adaltas/oidc-dcr:$VERSION \
  docker://registry.internal/adaltas/oidc-dcr:$VERSION
```

## Using a custom image

Any image providing `sh`, `curl`, `jq` and `kubectl` can be used instead, for example one built from the [`image/Dockerfile`](../image/Dockerfile):

```yaml
oidc-dcr:
  image:
    registry: registry.internal
    repository: my-team/dcr-runner
    tag: "1.0.0"
```

## Custom CA certificate

When `tls.certificate` is set, the CA certificate is passed to `curl` with the `--cacert` option. No package installation nor trust store update is required.
