# Development container (Docker and Podman)

This directory builds the Debian-based `dev-dotfiles-debian` development image with dotfiles, compilers, GitHub/GitLab clients, and coding agents. **This README is the single operational guide** for Docker/Podman startup, persistence, upgrades, and troubleshooting. Repository and agent-maintenance rules live in [`../../AGENTS.md`](../../AGENTS.md).

## Contents

- [Choose the right image](#choose-the-right-image)
- [Start a project sandbox](#start-a-project-sandbox)
- [Launcher settings](#launcher-settings)
- [Manual Docker and Podman commands](#manual-docker-and-podman-commands)
- [Storage, upgrades, and migration](#storage-upgrades-and-migration)
- [GitHub CLI authentication](#github-cli-authentication)
- [Docker-in-Docker](#docker-in-docker)
- [Local AI and host Ollama](#local-ai-and-host-ollama)
- [Installed tools and verification](#installed-tools-and-verification)

## Choose the right image

| Image | Home storage and launch flags |
| --- | --- |
| `ghcr.io/arran4/dev-dotfiles-debian:latest` **built from this repository after the home-seed release** | Primary `Dockerfile` stores the prepared home in an archive outside `/home/user`. The default launchers mount an independent per-project `-project-home` volume at `/home/user` and set `DEV_HOME_VOLUME_INIT=1`. The image has label `io.github.arran4.dev-dotfiles.home-seed=1`. |
| Older published images or locally cached `:latest` without that label | The same launchers retain the compatible legacy `-codex`, `-agy`, `-gh`, and `-glab` volumes, using `DEV_FORGE_VOLUME_INIT=1`. They do **not** mount `/home/user` or attempt to unpack a missing seed. |
| `dev-dotfiles-home-volume:trial` | Optional, locally built trial from an **older, unseeded** base image via `Dockerfile.home-volume`. It uses an isolated `-trial` container and `-home` volume. Rebuild a prior unlabelled trial to use it for new sandboxes with the updated launchers; existing named trial containers can still be resumed. Do not wrap a newly seeded published image: its baked home is deliberately empty. |

The new primary Dockerfile and the launchers are committed together, but **a repository merge is not an image publication**. `:latest` changes only when the Docker release workflow successfully builds and pushes it; currently running containers and locally cached older image layers do not change. To see the local image capability, use `docker image inspect --format '{{index .Config.Labels "io.github.arran4.dev-dotfiles.home-seed"}}' ghcr.io/arran4/dev-dotfiles-debian:latest` (substitute `podman` as needed). The normal launcher uses the supported published image; no trial-image build or host checkout is required to create a new seeded home **once that image has been released and pulled**.

## Start a project sandbox

Apply chezmoi-managed [`../../dot_local/bin/executable_run-dev-podman.sh`](../../dot_local/bin/executable_run-dev-podman.sh) and [`../../dot_local/bin/executable_run-dev-docker.sh`](../../dot_local/bin/executable_run-dev-docker.sh) to install `~/.local/bin/run-dev-podman.sh` and `~/.local/bin/run-dev-docker.sh`; include `~/.local/bin` in `PATH`. Run from the host project directory to bind-mount it at `/workspace`:

```sh
cd ~/Documents/Projects/my-project
run-dev-podman.sh
# Or: run-dev-docker.sh
```

Both launchers default to `ghcr.io/arran4/dev-dotfiles-debian:latest`; they use an existing local image offline and pull only when it is missing. To adopt a *newly released image* rather than a cached old one, explicitly pull it **before creating a new sandbox**:

```sh
podman pull ghcr.io/arran4/dev-dotfiles-debian:latest
# Or: docker pull ghcr.io/arran4/dev-dotfiles-debian:latest
```

No launcher uses `--rm`, bind-mounts host credentials, or passes the host Docker/Podman socket. A stopped named container is resumed without pulling or recreating it; a running one prints the `exec` command for an additional shell. In particular, an existing legacy `dev-agent-<name>` container continues to run with its original image and mounts even when `:latest` has been updated. An existing published home container `dev-agent-<name>-home` takes precedence when both exist. **Existing legacy sandboxes are not silently migrated.** To create a *separate*, fresh published home sandbox for the same project after pulling a seeded release:

```sh
DEV_NEW_HOME=1 run-dev-podman.sh
# Or: DEV_NEW_HOME=1 run-dev-docker.sh
```

This creates or resumes `dev-agent-<name>-home`, with a new `dev-agent-<name>-project-home` volume, leaving `dev-agent-<name>` and all old volumes untouched. It does **not** copy existing `gh`, Codex, Gemini, GitLab, shell history, or container-layer data into the new home. See [legacy-to-published-home migration](#storage-upgrades-and-migration) before removing anything. `DEV_NEW_HOME=1` fails safely if the locally selected image does not advertise the seed. A changed image tag, mount mode, or launcher flag never changes a stopped container's existing mounts; backing up and intentionally recreating the container is required to adopt a new image. Docker and Podman have independent container/volume stores.

### Launcher settings

Set environment variables on invocation, e.g. `SANDBOX_NAME=my-project DEV_WORKSPACE_MODE=volume run-dev-podman.sh`:

| Setting | Default | Effect |
| --- | --- | --- |
| `SANDBOX_NAME` | Current directory basename | Normalized lowercase per-project name for containers/volumes. |
| `DEV_IMAGE` | `ghcr.io/arran4/dev-dotfiles-debian:latest` | A published tag is checked for the home-seed label. Non-published overrides must already be present and advertise the seed; they retain the separate `-trial` layout. |
| `DEV_NEW_HOME` | `0` | `1` bypasses an existing published **legacy** container in favour of a separate seeded published home sandbox; requires a seeded image. Does not import any old volumes. |
| `DEV_WORKSPACE_MODE` | `bind` | `bind` = current host checkout at `/workspace`; `volume` = persistent `-workspace` volume; `container` = outer container writable layer. `/workspace` is independent of home. |
| `DEV_HOME_MODE` | `volume` | On seeded images, `volume` mounts the persistent project home, `container` uses the outer writable layer. An unseeded published image requires its legacy mounts. |
| `DEV_DIND` | `0` | `1` enables a privileged nested Docker daemon, not the host daemon socket. |
| `DEV_DIND_PERSIST` | `0` | With `DEV_DIND=1`, `1` mounts a separate persistent `-docker` volume at `/var/lib/docker`. |
| `DEV_DOCKER_HOST_GATEWAY` | `0` | Docker launcher only: `1` adds native Linux's `host.docker.internal:host-gateway` mapping. |

Neither launcher takes positional arguments. A named workspace volume is shared by old and new layouts *only when deliberately selected* with `DEV_WORKSPACE_MODE=volume` and the same project name; it is never imported into home. `DEV_HOME_MODE=container DEV_WORKSPACE_MODE=container` is disposable **on outer-container removal**, not on stop/start. On Podman, the launcher uses rootless `--userns=keep-id:uid=1000,gid=1000`; Docker omits that flag. Check host bind-mount ownership against the image's default UID/GID `1000:1000`, especially for rootless Docker.

### Optional old-base trial

The trial is no longer needed for the ordinary published-home workflow. For an isolated experiment with an old, *unseeded* base image, build from the dotfiles repository root using the same engine as the launcher:

```sh
podman build -f containers/dev-dotfiles-debian/Dockerfile.home-volume \
  --build-arg BASE_IMAGE=ghcr.io/arran4/dev-dotfiles-debian:<older-unseeded-tag> \
  --build-arg IMAGE_VERSION=home-volume-trial-1 \
  -t dev-dotfiles-home-volume:trial .
DEV_IMAGE=dev-dotfiles-home-volume:trial run-dev-podman.sh
```

Replace `<older-unseeded-tag>` with a real existing tag or local image reference; this placeholder is not a runnable image name. For Docker, substitute `docker build` and `run-dev-docker.sh`. The updated trial image carries the same capability label and keeps the historical `dev-agent-<name>-trial`/`dev-agent-<name>-home` names, isolated from the published home volume. Custom/unlabelled images cannot be used to create new homes because they might not include an archive or the seeding entrypoint.

## Manual Docker and Podman commands

The launchers are the preferred workflow because they check image capabilities and preserve old containers. These examples are specifically for a *verified seeded* published image, not an older `:latest` cache. Run from the host checkout you intend to edit; choose a project name with no existing conflicting container.

### Seeded published image: Podman

```sh
name=my-project
workspace=$(pwd -P)
podman run -it --name "dev-agent-${name}-home" --restart=no \
  --userns=keep-id:uid=1000,gid=1000 --hostname "agent-sandbox-${name}" \
  --env DEV_HOME_VOLUME_INIT=1 --workdir /workspace \
  --mount "type=bind,src=${workspace},dst=/workspace,rw" \
  --mount "type=volume,src=dev-agent-${name}-project-home,dst=/home/user" \
  ghcr.io/arran4/dev-dotfiles-debian:latest
```

For Docker, substitute `docker run` and omit `--userns`. To use a named workspace instead of a bind mount, replace the workspace mount with `--mount "type=volume,src=dev-agent-${name}-workspace,dst=/workspace"` and add `--env DEV_VOLUME_INIT=1`. Omit that mount entirely for an outer-container-only workspace. A seeded home can likewise use the container writable layer if the home mount is omitted; retain `DEV_HOME_VOLUME_INIT=1`. Do **not** use `--rm` if data exists only in a writable layer. `/workspace` is independent of home, not a symlink into it; `~/workspace` may link **to** `/workspace`. The home initializer does not populate or modify `/workspace`.

### Historical published images

Older published images do not have a home archive and need the four legacy mounts: `/home/user/.codex` (`-codex`), `/home/user/.gemini` (`-agy`), `/home/user/.config/gh` (`-gh`) and `/home/user/.config/glab-cli` (`-glab`), with `DEV_FORGE_VOLUME_INIT=1`. The launchers retain these mounts for an unseeded local image and resume historical `dev-agent-<name>` containers unchanged. Do not manually set `DEV_HOME_VOLUME_INIT=1` or mount a whole home on an unseeded image: the underlying home files would be hidden. An older image with a new seeded image tag is still older until actually pulled.

## Storage, upgrades, and migration

| Path | Lifetime and purpose |
| --- | --- |
| `/home/user` | On a newly created published seeded sandbox, `dev-agent-<name>-project-home` by default; on a trial, `dev-agent-<name>-home`. Old published sandboxes persist only the four separately mounted agent/forge paths. |
| `/workspace` | Host bind mount, independent `-workspace` volume, or outer-container writable layer regardless of home layout. |
| `/var/lib/docker` | Nested Docker's outer-container writable layer by default; `-docker` volume only with `DEV_DIND_PERSIST=1`. |
| `/usr/local/share/dev-dotfiles-debian/home-seed.tar` | Prepared home archive baked into seeded images, outside `/home/user`. |
| `/usr/local/share/dev-dotfiles-debian/home-seed-version` | Seed version based on build/release identifier and archive digest. |
| `~/.dev-dotfiles-seed-version` | Version successfully applied to the current project home. |

**Stop versus remove:** Stop/start preserves the *same* container's writable layer, including an unmapped workspace and nested Docker data. Removing/recreating discards that layer. Bind mounts and named volumes have independent lifetimes; removing the container does not remove named volumes unless explicitly requested. A persistent home does not make an unmapped workspace persistent across recreation. Existing container image/mount settings are not updated on restart.

**Seed initialization and upgrades:** `DEV_HOME_VOLUME_INIT=1` applies the prepared archive on first start. The same version skips reapplication. Recreating the named container with a newer *seeded* image and the same home volume overlays matching seeded paths; paths absent from the new archive remain. Known GitHub/GitLab/Codex/Gemini authentication/session files and shell history are excluded from subsequent overlay extraction. **Other locally edited seeded dotfiles may be overwritten; not every third-party secret is excluded. Back up your custom configuration before upgrading.** The version marker advances only after successful extraction. The initializer does not prove that the target is a named volume: **never bind-mount your host home onto `/home/user`**. A restart by itself does not run a new image, even if `:latest` has moved.

**Upgrade a published-home sandbox:** Back up configuration and any home/workspace data that lives only in the container writable layer. Pull the new published image, stop and remove *only* `dev-agent-<name>-home` (without `--volumes` or `-v`), and rerun from the same project directory and name. Keep `dev-agent-<name>-project-home` and any independent `-workspace`/`-docker` volumes. Verify the result before removing backups; the next start overlays the new image seed and does not delete volume-only files. Docker and Podman volume names are not interchangeable across engines.

**Legacy-to-published-home migration:** The new `-project-home` volume does **not** import any data from legacy `-codex`, `-agy`, `-gh`, or `-glab` volumes, or a legacy container's unmounted home. `DEV_NEW_HOME=1` is a safe parallel *fresh start*, not an automated migration. To transfer existing credentials and configuration, stop the legacy container, back up its layer and volumes, initialize a new home sandbox, then copy the selected old volume contents into the corresponding home subdirectories using a separate migration container. Check ownership, any unmounted shell configuration, project data, and authentication before deleting old state. Never nest the four legacy volumes under the new whole-home mount: they obscure seeded files. The separate old and new container names allow keeping both until the new environment is verified. Avoid running both concurrently against the same writable project workspace unless that sharing is intended. Keyring-backed logins may require reauthentication.

**Trial-to-published-home migration:** The earlier `-home` trial volume is deliberately different from the published `-project-home` volume. Back it up and transfer selected data explicitly, as above; switching `DEV_IMAGE` or removing `-trial` does not migrate the trial home. Do not base a fresh trial build on a seeded published image (its baked home is empty).

**Deliberate cleanup:** Check the exact container names, image layouts, and mount sources before deleting anything. Do not run legacy five-volume cleanup commands against a seeded home or remove a `-project-home`/`-home` volume while it contains the only copy of credentials or other work.

## GitHub CLI authentication

In the seeded published image `gh` configuration lives under `/home/user/.config/gh` in the per-project `-project-home` volume. Old published sandboxes retain their `-gh` volume; trial sandboxes use their `-home` volume. **Persistent credentials do not guarantee a permanently valid token.** Signing in from many containers can create distinct OAuth authorizations and can revoke older tokens. Agents for the same account share API rate limits. A `gh auth status` failure may reflect rate limiting or connectivity rather than expiry; see [GitHub CLI issue #14053](https://github.com/cli/cli/issues/14053).

### Diagnose first; do not expose secrets

Inside the affected container:

```sh
for name in GH_TOKEN GITHUB_TOKEN; do
  if [ -n "$(printenv "$name" 2>/dev/null)" ]; then
    printf '%s is set (value hidden)\n' "$name"
  fi
done

gh api /user --jq .login
gh api /rate_limit --jq '{core: .resources.core, graphql: .resources.graphql}'
gh auth status -h github.com --json hosts
```

`GH_TOKEN` and `GITHUB_TOKEN` can override persisted login. A successful `/user` request confirms authentication for that request even if `gh auth status` reports an error. A rate-limit `403` or `429` warrants reducing calls and observing reset/retry time, not reauthorizing. An HTTP `401` with the intended token is consistent with invalid credentials; DNS, TLS, and `5xx` errors are separate problems. Never publish `gh auth token`, `gh auth status --show-token`, `hosts.yml`, raw secrets, or verbose HTTP traces. Multiple tokens for one user do not supply independent personal API quotas; see [GitHub REST rate limits](https://docs.github.com/en/rest/using-the-rest-api/rate-limits-for-the-rest-api).

### Sign in or recover

Only after confirming that authentication is needed, use HTTPS Git transport and include `workflow` scope for GitHub Actions changes:

```sh
gh auth login -h github.com -p https -s workflow
gh api /user --jq .login
```

For an existing login needing reauthorization or an additional scope, run `gh auth refresh -h github.com -s workflow` and verify `/user`. This does **not** guarantee an automatically rotating OAuth refresh token. Do not reauthenticate all running sandboxes in a loop, attempt `offline_access`, or automatically reauthenticate on startup. A revoked token may require a new authorization. For headless device login, enter the CLI code in the host browser at <https://github.com/login/device>; `xdg-open` failure alone does not establish login failure. See [login](https://cli.github.com/manual/gh_auth_login), [refresh](https://cli.github.com/manual/gh_auth_refresh), and [token expiration and revocation](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/token-expiration-and-revocation).

### Shared authentication: explicit trust trade-off

For *legacy* sandboxes, trusted projects may replace their per-project `-gh` mount in a manual command with `--mount "type=volume,src=dev-agent-shared-gh,dst=/home/user/.config/gh"`. Authenticate once from a container using that volume. Do not mount host credentials or share the volume with less-trusted sandboxes; every agent using it gets the same permissions and can change the saved login. Avoid concurrent `gh auth login`, `refresh`, and `logout` against the same volume. Sharing does not create separate API quotas or import existing logins. A seeded sandbox's *whole home* is **not** equivalent to sharing only its `gh` configuration; do not casually share a home volume between projects. A shared `gh` mount in a manual seeded command would also hide the configuration beneath it; change mounts only after safeguarding state and recreating the container.

## Docker-in-Docker

Set `DEV_DIND=1` with either launcher to start a **nested Docker daemon**, never the host socket. The outer container becomes `--privileged`: rootless Podman confines it to the invoking user's namespace, while rootful Docker's privileged mode grants broad host-level capabilities and significantly reduces isolation. Do **not** pass `/var/run/docker.sock`, `/run/docker.sock`, or the host Podman socket into the sandbox. The entrypoint refuses a non-removable preexisting socket mount.

```sh
# Data survives stop/start of this outer container, not its removal:
DEV_DIND=1 run-dev-podman.sh

# Nested Docker data also survives outer-container recreation:
DEV_DIND=1 DEV_DIND_PERSIST=1 run-dev-podman.sh
```

For Docker use `run-dev-docker.sh`. For a manual command add `--privileged --env DEV_DIND=1`, and optionally `--mount "type=volume,src=dev-agent-${name}-docker,dst=/var/lib/docker"`. That extra volume is **not required for ordinary nested Docker**. Without it, `/var/lib/docker` is in the outer writable layer; a `--tmpfs` mount is stop-volatile and requires separate size/storage-driver testing. Home and workspace volumes never store nested Docker's image store.

To verify nested Docker inside the container without pulling an inner base image:

```sh
docker info

tmp=$(mktemp -d)
cat > "$tmp/main.go" <<'EOF'
package main
func main() {}
EOF
CGO_ENABLED=0 go build -o "$tmp/smoke" "$tmp/main.go"
cat > "$tmp/Dockerfile" <<'EOF'
FROM scratch
COPY smoke /smoke
ENTRYPOINT ["/smoke"]
EOF
docker build -t dev-dind-smoke "$tmp"
docker run --rm dev-dind-smoke
rm -rf "$tmp"
```

This checks the nested build, image store, and runtime without accessing an inner registry.

## Local AI and host Ollama

The container can use a host Ollama server without embedding its daemon or models. The entrypoint seeds `~/.config/opencode/opencode.json` only when absent, defaulting to `ollama/qwen2.5-coder:7b` at `http://host.docker.internal:11434/v1`. A changed home seed can overlay matching configuration files on recreation; back up custom agent settings and third-party credentials before seed upgrades.

On the host, pull the model and expose Ollama on the bridge:

```sh
ollama pull qwen2.5-coder:7b
OLLAMA_HOST=0.0.0.0:11434 ollama serve
```

For systemd-managed Ollama, set `Environment="OLLAMA_HOST=0.0.0.0:11434"` under `[Service]` in a service override, then run `sudo systemctl daemon-reload && sudo systemctl restart ollama`. Listening on `0.0.0.0` exposes port 11434 on host interfaces; restrict it with firewall rules for your trusted network. The local Ollama server does not require an API key by default.

Podman normally supplies `host.docker.internal` and `host.containers.internal`; Docker Desktop supplies the former. On **native Linux Docker**, set `DEV_DOCKER_HOST_GATEWAY=1` at container creation, or add `--add-host host.docker.internal:host-gateway` to a manual command for either image. This flag cannot be added to an already created container via `start`.

Inside the container:

```sh
getent hosts host.docker.internal
curl -fsS http://host.docker.internal:11434/v1/models | jq .
opencode --auto
```

The generated OpenCode configuration is equivalent to:

```json
{
  "$schema": "https://opencode.ai/config.json",
  "provider": {
    "ollama": {
      "npm": "@ai-sdk/openai-compatible",
      "name": "Ollama (host)",
      "options": {"baseURL": "http://host.docker.internal:11434/v1"},
      "models": {"qwen2.5-coder:7b": {"name": "Qwen2.5 Coder 7B"}}
    }
  },
  "model": "ollama/qwen2.5-coder:7b"
}
```

The OpenCode `tools` setting is a top-level map, not a model-level `"tools": true` boolean. If local-model tool calls are unreliable, examine the Ollama context window before changing tool settings.

### Optional additional agents

These agents are **not baked into the image**. Install only where required. For seeded homes, user-space installs under `/home/user` survive container recreation, while installs in the outer container system layer do not. Prefer isolated Python installs over system-wide `pip`.

**Aider:** `pipx install aider-chat` (or `uv tool install --force --python python3.12 --with pip aider-chat@latest` as appropriate). Point the Ollama transport at the host endpoint **without** `/v1`:

```sh
export OLLAMA_API_BASE=http://host.docker.internal:11434
aider --model ollama_chat/qwen2.5-coder:7b
```

**Zero (`Gitlawb/zero`):** review its upstream installer before running `curl -fsSL https://raw.githubusercontent.com/Gitlawb/zero/main/scripts/install.sh | bash`, then:

```sh
zero setup ollama \
  --base-url http://host.docker.internal:11434/v1 \
  --model qwen2.5-coder:7b
zero providers list
zero models list
zero doctor
```

**jcode (`1jehuang/jcode`):** review its installer before running `curl -fsSL https://jcode.sh/install | bash`, then configure a no-auth local profile:

```sh
jcode provider add host-ollama \
  --base-url http://host.docker.internal:11434/v1 \
  --model qwen2.5-coder:7b \
  --no-api-key \
  --set-default
jcode --provider-profile host-ollama auth-test
```

## Installed tools and verification

The primary image uses `debian:${DEBIAN_RELEASE}-slim` (default `stable`), UID/GID `1000:1000`, zsh, and passwordless sudo. The primary Dockerfile accepts `USER_NAME`, `USER_UID`, and `USER_GID`; the launchers assume default IDs. The build installs tools before applying chezmoi and snapshots the prepared user home *after* setup. The archive lives outside `/home/user`, so mounting a fresh home volume cannot hide it. The primary image labels its seeded-home capability; the release workflow continues to build the primary Dockerfile. A successful merge is not proof that the revised `:latest` has been pushed.

Tools include Git, Git LFS, `git-credential-oauth`, `gh`, `glab`, zsh, fish, tmux, vim/Neovim, less, `git-delta`, kdiff3, ripgrep, fd, jq, ShellCheck, shfmt, clang, CMake, Ninja, Go, Node.js, Python, Java/Maven, Flutter, Docker CLI/daemon, Buildx, and Compose. Agent CLIs include Codex, Antigravity (`agy`), Mini SWE Agent (`mini`), OpenCode, Claude Code, GitHub Copilot CLI, and Qwen. `difftastic`, `zellij`, and desktop Hyprland/KDE tools are not installed. Jules CLI is intentionally omitted because its installer introduced layer ownership incompatible with normal rootless Podman subordinate-ID mapping; the primary Dockerfile retains a disabled ownership-normalization recipe.

From the repository root:

```sh
sh containers/dev-dotfiles-debian/test-home-volume.sh
sh containers/dev-dotfiles-debian/test-launchers.sh
sh -n dot_local/bin/executable_run-dev-docker.sh
sh -n dot_local/bin/executable_run-dev-podman.sh
```

The home-volume test covers first initialization, same-version restart, updated seed preservation, independent workspace, and failed-upgrade retry. The launcher test mocks both engines to check seeded versus legacy published tags, published-home separation, explicitly bypassing an existing legacy container, trial isolation, missing-image handling, and safe stopped-container resumption. A successful CI build and live rootless Podman/Docker lifecycle, mount ownership, versioned recreation, and credential migration verification are required before replacing sandboxes or deleting any original volumes. Keep documentation aligned with **actually published image capabilities and implemented scripts**, not a merely merged prototype.
