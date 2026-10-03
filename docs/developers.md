# Developers

## CI/CD

The chart use [Release Please](https://github.com/googleapis/release-please) to automate CHANGELOG generation, to create GitHub releases, and to bump versions.

The [`release-and-publish.yaml`](./.github/workflows/release-and-publish.yaml) workflow publishes the chart to the [Quay](https://quay.io/repository/adaltas/oidc-dcr) repository.

## Job image

The registration job runs the [`quay.io/adaltas/oidc-dcr-job`](https://quay.io/repository/adaltas/oidc-dcr-job) image, built from the [`image/Dockerfile`](../image/Dockerfile). It embeds all the script dependencies. The release workflow builds it for `linux/amd64` and `linux/arm64` and pushes it with the chart version as tag, before publishing the chart.

To build it locally:

```bash
docker build -t oidc-dcr-job:dev image
```

## Test

This chart uses [Helm Unittest](https://github.com/helm-unittest/helm-unittest#get-started) to execute unit tests.

```bash
version=$(helm version --template '{{.Version}}')
# Using Helm 4
if [[ ${version:1:1} == '4' ]]; then
helm plugin install \
  https://github.com/helm-unittest/helm-unittest.git --verify=false
# Or using Helm 3
else
  helm plugin install https://github.com/helm-unittest/helm-unittest.git
fi
```

Run the following command to execute the tests.

```bash
helm unittest .
```

All the tests are located in the `tests` folder.
