# GitHub CLI authentication in development sandboxes

## Why a persisted login can stop working

The development container persists `gh` credentials in the volume mounted at `/home/user/.config/gh`. Persistence does not prevent GitHub from revoking a token. The existing README examples use a separate `dev-agent-${name}-gh` volume for every project; authorizing GitHub CLI independently in many project sandboxes can exhaust GitHub's limit of ten active OAuth tokens per user, application and scope combination. When the limit is exceeded, GitHub can revoke an older token that is still present in its volume. This is a possible cause of invalid-token messages, not proof of the reason a particular token was revoked.

`gh auth refresh` is an interactive reauthorization/scope-adjustment command, **not** a promise that GitHub CLI will receive, persist and automatically rotate an OAuth refresh token. Do not request `offline_access` as a workaround: an expiring access token requires a compatible refresh-token lifecycle, which this image does not implement. Do not add a background reauthentication job or automatically run `gh auth refresh` on every container start; creating more tokens can make the problem worse.

References: [GitHub token expiration and revocation](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/token-expiration-and-revocation), [GitHub CLI auth refresh](https://cli.github.com/manual/gh_auth_refresh), [GitHub OAuth expiring access tokens](https://docs.github.com/en/apps/oauth-apps/building-oauth-apps/authorizing-oauth-apps#expiring-access-tokens).

## Reuse one credential volume for trusted projects

The existing project-specific `gh` volumes remain supported when credentials must be isolated. To **opt in** to sharing the same GitHub CLI login across your own trusted sandboxes, change only this mount in the Podman or Docker `run` example in [the container README](README.md) or [the root README](../../README.md):

```sh
# Existing independent credentials for each project:
--mount type=volume,src="dev-agent-${name}-gh",dst=/home/user/.config/gh

# Optional shared credentials across projects, on the same container engine:
--mount type=volume,src=dev-agent-shared-gh,dst=/home/user/.config/gh
```

Leave the project-specific `codex`, `agy` and `glab` volumes unchanged. With the shared mount, authenticate **once** from any container using it. All other containers mounting `dev-agent-shared-gh` then use the same login. Podman and Docker volumes are managed separately; this does not make the host's GitHub CLI credentials available inside the container. Existing project volumes are not modified or deleted, and an existing named container must be recreated to change its mounts. For the disposable `--rm` workflow, use the revised command on its next launch. For a persistent sandbox, preserve its workspace and agent-state volumes when recreating its container, and do not remove its previous `gh` volume until you have verified the new setup.

**Security trade-off:** Every agent with access to the shared volume also has access to the same GitHub credentials, including permission to operate on repositories outside its current `/workspace`. Only share it among sandboxes that should have the same GitHub privileges; retain per-project credentials or use separate narrowly scoped authentication for untrusted or restricted work. The volume stores secrets, so never commit its files, copy them into an image, or mount the host's whole home directory.

## Sign in or recover credentials

For a new volume, authenticate with HTTPS Git transport and the `workflow` scope needed when editing GitHub Actions workflow files:

```sh
gh auth login -h github.com -p https -s workflow
gh auth status -h github.com
```

If the volume already contains the intended account but `gh auth status -h github.com` reports an invalid token, reauthorize it with the same required scope:

```sh
gh auth refresh -h github.com -s workflow
gh auth status -h github.com
```

`gh` uses a device authorization flow in headless containers. When the CLI prints a one-time code, open <https://github.com/login/device> in the **host browser**, enter the code, and return to the container. The message saying `xdg-open` or another browser opener is missing only indicates that the container could not open a graphical browser itself; it does not require installing a browser inside the container. If authorization is declined, expires, or the account no longer has access, the command still cannot complete successfully. Do not paste the resulting access token into shell history or debug logs.

If `gh` is still using unexpected credentials, check for an explicitly configured `GH_TOKEN` or `GITHUB_TOKEN`: environment tokens take precedence over stored credentials. Never print either token or run `gh auth status --show-token` while sharing logs. If a token has been revoked, it cannot be restored; a new authorization is required. Use the same shared volume for subsequent trusted project launches to avoid generating another independent OAuth token for each project.
