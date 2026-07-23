# Keycloak DCR registration

The `oidc-dcr` chart provides automatic client's registration with OIDC providers supporting the OpenID Connect Dynamic Client Registration (DCR) protocol (such as Keycloak). It is used to automate the registration of applications that need OIDC authentication without any manual intervention and elevated privileges.

## Architecture

The chart creates a Kubernetes Job that executes a bash script to perform the dynamic client registration. The script sends a JSON payload to the specified HTTP DCR registration endpoint and processes the response to extract relevant information (like client ID and secret). This information is then stored in a Kubernetes Secret for use by other applications.

## Chart execution

To ensure the DCR registration is executed before the main application deployment and to be able to orchestrate the execution order, the chart set [Helm](https://helm.sh/docs/topics/charts_hooks/) and [Argo CD](https://argo-cd.readthedocs.io/en/stable/user-guide/sync-waves/) orchestrations hooks to `pre-install`/`pre-upgrade` for Helm and `PreSync` for Argo CD.

All the DCR-related resources (ConfigMap, Service, ServiceAccount, Role, RoleBinding) are created in first. Then, the Job is executed using all the ressources previously created. The Job still have a negative hook-weight ensuring any other `pre-install`/`pre-upgrade` or `PreSync` job from the main chart is executed after.

## Example

- [Configuration](./docs/configuration.md)
- [Data mapping](./docs/data-mapping.md)
- [Headlamp integration](./docs/example-headlamp.md)
- [Argo CD integration](./docs/example-argocd.md)

## Roadmap

- Validate/enrich the configuration
- Respect Helm documentation best-practices
- Fix error "Resource not found in cluster" in Argo CD
- Any other Helm best practices
