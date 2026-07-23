# Developers

## CI/CD

The chart use [Release Please](https://github.com/googleapis/release-please) to automate CHANGELOG generation, to create GitHub releases, and to bump versions.

The [`release-and-publish.yaml`](./.github/workflows/release-and-publish.yaml) workflow publishes the chart to the [Quay](https://quay.io/repository/adaltas/oidc-dcr) repository.

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
