# Pipeline instructions:

## Quay.io setup

[Open Quay.io](https://quay.io/repository/)

1. Create a "Robot Account" in the profile settings (name: "oidc-dcr" for example)
2. Give the robot a "write" access to the repo
3. Copy the robot credentials (name (format `<QuayUsername>+<robotName>`) and token)

## Github repository setup

[Open the repository](https://github.com/adaltas/oidc-dcr)

1. Go to `Settings` > `Secrets and variables` > `Actions`
2. Add 2 repository secrets:
   - `QUAY_TOKEN` (with the Quay robot token)
   - `QUAY_USERNAME` (with the Quay robot username)
3. Then, go to `Actions` > `General` and check "Allow GitHub Actions to create and approve pull requests" (at the very bottom)

## Add the workflow and config files

[All the needed files are in the following PR](https://github.com/adaltas/oidc-dcr/pull/5)

The PR contains:

- `.github/workflows/release-and-publish.yaml`
- `release-please-config.json`
- `.release-please-manifest.json`
