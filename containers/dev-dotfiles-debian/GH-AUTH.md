# GitHub CLI authentication in development sandboxes

## Diagnose failures before reauthorizing

The development container persists `gh` credentials in the volume mounted at `/home/user/.config/gh`. A persisted token may be revoked, but **`gh auth status` reporting an invalid token is not proof of revocation**. GitHub CLI [issue #14053](https://github.com/cli/cli/issues/14053) documents that a rate-limit response, network error or server failure can produce the same message. With several coding-agent containers running concurrently, diagnose this before starting another OAuth flow.

In the affected container, run:

```sh
# Check for environment credentials that override the saved login, without printing them.
for name in GH_TOKEN GITHUB_TOKEN; do
  if [ -n "$(printenv "$name" 2>/dev/null)" ]; then
    printf '%s is set (value hidden)\n' "$name"
  fi
done

# Check the actual API response and rate limits rather than relying only on auth status.
gh api /user --jq .login
gh api /rate_limit --jq '{core: .resources.core, graphql: .resources.graphql}'

# Display the underlying auth-status errors, without printing access tokens.
gh auth status -h github.com --json hosts
```

Do not paste a raw token, `gh auth token`, `gh auth status --show-token`, `hosts.yml` or verbose HTTP traces into logs or issues. If an environment token is present, it takes precedence over the volume's credentials; correct the environment source before changing the saved login. A successful `/user` call establishes that `gh` can authenticate that request, even if `gh auth status` reports an error. A `403`/`429` response mentioning rate limits calls for reducing requests and observing the reset/retry time, **not** running `gh auth refresh`. An HTTP `401` on `/user` with the expected token is consistent with a genuinely invalid credential. DNS, TLS and `5xx` failures are separate network/service problems.

Multiple tokens for the same user do **not** give coding agents independent personal API-rate-limit budgets: authenticated requests made on your behalf generally count toward the same user limit. Reusing one credential avoids unnecessary OAuth authorizations but does not remove contention between simultaneously running agents. See [GitHub REST API rate limits](https://docs.github.com/en/rest/using-the-rest-api/rate-limits-for-the-rest-api).

## Why a persisted login can stop working

The existing README examples use a separate `dev-agent-${name}-gh` volume for every project. Independently authorizing GitHub CLI in many project sandboxes can exhaust GitHub's limit of ten active OAuth tokens per user, application and scope combination. GitHub also limits creation to ten tokens per hour. Exceeding the active-token limit can revoke an older token that is still being used by a running container. Eight simultaneously running containers do not by themselves prove the limit was reached: previously started containers, different scopes and other active CLI sessions affect the count. This is a possible cause, not a verified diagnosis of a specific failed login.

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

Leave project-specific `codex`, `agy` and `glab` volumes unchanged. With the shared mount, authenticate **once** from any container using it. Other containers mounting `dev-agent-shared-gh` then use the same login. Podman and Docker volumes are managed separately; this does not make the host's GitHub CLI credentials available inside the container. Existing project volumes are not modified or deleted, and an existing named container must be recreated to change its mounts. For the disposable `--rm` workflow, use the revised command on its next launch. For a persistent sandbox, preserve its workspace and agent-state volumes when recreating its container, and do not remove its previous `gh` volume until you have verified the new setup.

**Concurrency and security trade-offs:** Every simultaneous agent with access to the shared volume can use the same GitHub identity, operate on repositories outside its current `/workspace` and modify the saved CLI credentials. Do not run concurrent `gh auth login`, `gh auth refresh` or `gh auth logout` commands against a shared volume. Sharing does not provide independent API quotas or isolate scopes. Use it only for equally trusted sandboxes that should have the same GitHub privileges. Retain project-specific credentials or separately scoped tokens for restricted work. Never commit credentials, copy them into an image or mount the host's whole home directory.

PR #464's optional project-scoped **home volume** can persist credentials but does not prevent expiry/revocation or share authentication across projects. Evaluate the storage design independently; do not combine the two experiments or delete existing volumes as a shortcut to fixing authentication.

## Sign in or recover credentials

First follow the diagnostic steps above. Only if the saved token is actually invalid should you initiate a new authorization. For a new volume, authenticate with HTTPS Git transport and the `workflow` scope needed when editing GitHub Actions workflow files:

```sh
gh auth login -h github.com -p https -s workflow
gh api /user --jq .login
```

If the volume contains the intended account and a request to `/user` confirms the stored credentials are invalid, reauthorize with the required scope:

```sh
gh auth refresh -h github.com -s workflow
gh api /user --jq .login
```

`gh` can use a device authorization flow in headless containers. When the CLI prints a one-time code, open <https://github.com/login/device> in the **host browser**, enter the code, and return to the container. Failure to start `xdg-open` does not by itself establish that device authorization failed; check the command's eventual result. If authorization is declined, expires, or the account no longer has access, it cannot complete successfully. A revoked token cannot be restored; an independent new authorization is required. Do not reauthorize all running containers in a loop.
