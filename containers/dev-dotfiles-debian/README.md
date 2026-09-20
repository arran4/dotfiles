# Development container (Docker and Podman)

This directory builds the Debian-based `dev-dotfiles-debian` development image, with dotfiles, compilers, GitHub/GitLab clients, and coding agents. **This README is the single operational guide** for starting, maintaining, and troubleshooting its Docker and Podman containers. Repository and agent-maintenance instructions live in [`../../AGENTS.md`](../../AGENTS.md).

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

| Image | Availability | Home storage and launch flags |
| --- | --- | --- |
| `ghcr.io/arran4/dev-dotfiles-debian:latest` | **Published, default for both launchers** | Existing per-project `-codex`, `-agy`, `-gh`, and `-glab` volumes; `DEV_FORGE_VOLUME_INIT=1`. |
| `dev-dotfiles-home-volume:trial` | **Opt-in: build locally** with `Dockerfile.home-volume` | One versioned project-home volume, independent `/workspace`, and `DEV_HOME_VOLUME_INIT=1`. Select with `DEV_IMAGE=dev-dotfiles-home-volume:trial`. |

[PR #464](https://github.com/arran4/dotfiles/pull/464) merged an opt-in trial implementation into the repository; it did **not** publish the trial as `:latest`. The normal launchers now use the published image with its compatible legacy mounts, rather than assuming the trial is already built. Do not mix the two images' mount layouts, use `DEV_HOME_VOLUME_INIT=1` with the published tag, or assume that selecting the trial migrates old volumes. Revisit the layout when the published image actually includes home-volume initialization.

## Start a project sandbox

Apply the chezmoi-managed launcher sources [`../../dot_local/bin/executable_run-dev-podman.sh`](../../dot_local/bin/executable_run-dev-podman.sh) and [`../../dot_local/bin/executable_run-dev-docker.sh`](../../dot_local/bin/executable_run-dev-docker.sh) to install `~/.local/bin/run-dev-podman.sh` and `~/.local/bin/run-dev-docker.sh`. Put `~/.local/bin` on `PATH`. Run the launcher **from the project directory you want mounted**, not necessarily from the dotfiles directory:

```sh
cd ~/Documents/Projects/my-project
run-dev-podman.sh
# Or, for Docker:
run-dev-docker.sh
```

The default launcher selects `ghcr.io/arran4/dev-dotfiles-debian:latest`, reuses a local copy without needing network access, and pulls it if missing. A registry or network failure during a required pull produces a clear error without removing existing containers or volumes. The default host checkout is bind-mounted at `/workspace`; published-image authentication and agent volumes remain per project. Neither launcher uses `--rm`, passes the host Docker socket, or bind-mounts host credentials. To use another project, change host directories or specify `SANDBOX_NAME`.

A stopped named container is **resumed without pulling or recreating it**; a running one prints the `exec` command for an additional shell. The published layout uses `dev-agent-<name>`; the opt-in trial uses `dev-agent-<name>-trial`. A resumed container keeps its original image, mounts, and writable layer even if the launcher or image tag has since changed. Back up any data stored only in the container writable layer before intentionally recreating it.

### Optional locally built project-home trial

Only if testing the home-volume implementation, build the alternative image from the **dotfiles repository root** with the same engine you intend to run:

```sh
podman build -f containers/dev-dotfiles-debian/Dockerfile.home-volume \
  --build-arg BASE_IMAGE=ghcr.io/arran4/dev-dotfiles-debian:latest \
  --build-arg IMAGE_VERSION=home-volume-trial-1 \
  -t dev-dotfiles-home-volume:trial .

# From the desired host project directory:
DEV_IMAGE=dev-dotfiles-home-volume:trial run-dev-podman.sh
```

For Docker, substitute `docker build` and `run-dev-docker.sh`. `BASE_IMAGE` may point to a locally built primary image. For subsequent seed releases, change `IMAGE_VERSION` (prefer a release or commit identifier); the archive digest also contributes to the recorded version. The trial currently derives from the original image, so it does not remove the original baked-home layers. If an explicitly selected trial image is missing locally, the launcher reports the missing image instead of attempting an unqualified registry pull. No existing legacy volumes are migrated automatically.

### Launcher settings

Set environment variables on the invocation, e.g. `SANDBOX_NAME=my-project DEV_WORKSPACE_MODE=volume run-dev-podman.sh`:

| Setting | Default | Effect |
| --- | --- | --- |
| `SANDBOX_NAME` | Current directory basename | Normalized lowercase per-project name for containers and volumes. |
| `DEV_IMAGE` | `ghcr.io/arran4/dev-dotfiles-debian:latest` | Published image with legacy mounts by default. Non-published image overrides select the explicitly built project-home layout and `-trial` container. |
| `DEV_WORKSPACE_MODE` | `bind` | `bind` = current host checkout; `volume` = persistent `-workspace` volume; `container` = container writable layer only. |
| `DEV_HOME_MODE` | `volume` | Only configurable for the home-volume trial: `volume` = persistent `-home` volume; `container` = writable layer. The published layout requires `volume` and uses its four legacy mounts. |
| `DEV_DIND` | `0` | `1` enables a privileged **nested** Docker daemon, never the host daemon socket. |
| `DEV_DIND_PERSIST` | `0` | With `DEV_DIND=1`, `1` mounts a separate persistent `-docker` volume at `/var/lib/docker`. |
| `DEV_DOCKER_HOST_GATEWAY` | `0` | Docker launcher only: `1` adds native Linux's `host.docker.internal:host-gateway` mapping. |

A disconnected but persistent checkout uses `DEV_WORKSPACE_MODE=volume`. For a fully disposable **trial**, use `DEV_IMAGE=dev-dotfiles-home-volume:trial DEV_HOME_MODE=container DEV_WORKSPACE_MODE=container`. With the published layout, the legacy authentication volumes remain persistent even if the workspace is container-only. Neither launcher takes positional arguments. The Podman script uses rootless `--userns=keep-id:uid=1000,gid=1000`; the Docker script does not support that flag. Verify bind-mount ownership for the image's default UID/GID `1000:1000`, especially with rootless Docker.

## Manual Docker and Podman commands

The launchers are the preferred normal workflow. These commands show the actual mounts for manual customization. Run from the host checkout you intend to edit and choose a distinct `name` for the project.

### Published image: Podman

```sh
name=my-project
workspace=$(pwd -P)
podman run -it --name "dev-agent-${name}" --restart=no \
  --userns=keep-id:uid=1000,gid=1000 \
  --hostname "agent-sandbox-${name}" --env DEV_FORGE_VOLUME_INIT=1 \
  --workdir /workspace \
  --mount "type=bind,src=${workspace},dst=/workspace,rw" \
  --mount "type=volume,src=dev-agent-${name}-codex,dst=/home/user/.codex" \
  --mount "type=volume,src=dev-agent-${name}-agy,dst=/home/user/.gemini" \
  --mount "type=volume,src=dev-agent-${name}-gh,dst=/home/user/.config/gh" \
  --mount "type=volume,src=dev-agent-${name}-glab,dst=/home/user/.config/glab-cli" \
  ghcr.io/arran4/dev-dotfiles-debian:latest
```

For Docker, substitute `docker run`, omit Podman's `--userns` flag, and verify host checkout UID/GID permissions. To use a persistent named workspace instead of a bind mount, replace the workspace mount with `--mount "type=volume,src=dev-agent-${name}-workspace,dst=/workspace"` and add `--env DEV_VOLUME_INIT=1`.

### Opt-in project-home trial: Podman

```sh
name=my-project
workspace=$(pwd -P)
podman run -it --name "dev-agent-${name}-trial" --restart=no \
  --userns=keep-id:uid=1000,gid=1000 \
  --hostname "agent-sandbox-${name}" --env DEV_HOME_VOLUME_INIT=1 \
  --workdir /workspace \
  --mount "type=bind,src=${workspace},dst=/workspace,rw" \
  --mount "type=volume,src=dev-agent-${name}-home,dst=/home/user" \
  dev-dotfiles-home-volume:trial
```

For Docker, substitute `docker run` and omit Podman's `--userns` flag. For either engine, a separate named workspace uses the same `-workspace` mount and `DEV_VOLUME_INIT=1` as the published layout. Omit the workspace mount to clone a repository into the container's independent writable `/workspace`. Omitting both trial mounts makes a disposable experiment, but retain `DEV_HOME_VOLUME_INIT=1` for seeding the trial's writable home. Do **not** use `--rm` if needed data exists only in the container writable layer. `/workspace` is independent of home, not a symlink into it; `~/workspace` may be a convenience link **to** it. The initializer does not seed or modify `/workspace`.

## Storage, upgrades, and migration

| Path | Lifetime and purpose |
| --- | --- |
| `/home/user` | In the trial, a persistent project `-home` volume by default; with the published image, only selected agent/forge directories are separately mounted, and other home contents belong to the container writable layer. |
| `/workspace` | Host bind mount, independent `-workspace` volume, or container writable layer, regardless of the image layout. |
| `/var/lib/docker` | Nested Docker's outer-container writable layer by default; separate `-docker` volume only if requested. |
| `/usr/local/share/dev-dotfiles-debian/home-seed.tar` | Trial's image-home archive, outside the runtime home mount. |
| `/usr/local/share/dev-dotfiles-debian/home-seed-version` | Trial seed build identifier and archive digest. |
| `~/.dev-dotfiles-seed-version` | Version last successfully applied to the trial home. |

**Stop versus remove:** Stopping and starting the *same* container preserves its writable layer, including an unmapped `/workspace` and nested Docker data. Removing/recreating it discards that layer even if it uses the same image tag. Bind mounts and named volumes have separate lifetimes; removing the container does not remove named volumes unless explicitly requested. A persistent trial home does not make an unmapped workspace persistent across recreation. Switching images or changing mount modes never silently replaces a named container.

**Trial seeding:** `DEV_HOME_VOLUME_INIT=1` initializes the trial home from the prepared image archive on first start. The same seed version skips the overlay. A changed seed version overlays matching seeded configurations; paths absent from the seed are retained, and known GitHub/GitLab/Codex/Antigravity auth/session and shell-history paths are excluded on subsequent upgrades. Other locally modified seeded dotfiles **may be overwritten** and not every application secret path is protected. The version marker advances only after successful extraction. The initializer does not establish that the target is a named volume: **never bind-mount your host home to `/home/user`**.

**Upgrade a trial container:** Back up local configurations and any workspace data kept only in the container layer. Build a newer image with a new seed version, then stop and remove *only* the old named container object, not its volumes. Re-run with the same project name and volumes. A simple restart does not adopt a newer image. If launcher settings have changed, they apply only on creation of a new container.

**Legacy-to-trial migration:** Old sandboxes use `-workspace`, `-codex`, `-agy`, `-gh`, and `-glab` volumes. The trial's `-home` volume does not import any of them. Stop the legacy container and back up the volumes; transfer the old four agent/forge volumes to their matching paths in a new trial home using a separate migration container; retain or remount the workspace volume independently. Verify ownership, repository data, and authentication before deleting anything. Do **not** nest the old mounts inside the new home: they hide seeded files. Keyring-backed logins may need reauthentication. Docker and Podman maintain separate volume stores even when volume names match.

**Deliberate cleanup:** Identify whether a workspace is a host checkout, named volume, or writable layer before removing a sandbox. Never use legacy five-volume cleanup commands against a trial. Delete only the particular containers and volumes you explicitly intend to discard.

## GitHub CLI authentication

Published-image `gh` configuration lives under `/home/user/.config/gh` in the per-project `-gh` volume; the trial keeps that path in its `-home` volume. **Persistent credentials do not guarantee a permanently valid token.** Signing in from many project containers can create distinct OAuth authorizations and may lead to older tokens being revoked. Agents for the same account also share GitHub API rate limits. An `gh auth status` failure may be rate limiting or connectivity rather than token expiry; see [GitHub CLI issue #14053](https://github.com/cli/cli/issues/14053).

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

`GH_TOKEN` and `GITHUB_TOKEN` can override a persisted login. A successful `/user` request confirms authentication for that request even if `gh auth status` reports an error. A rate-limit `403` or `429` warrants reducing calls and observing the reset/retry time, not reauthorizing. An HTTP `401` with the intended token is consistent with invalid credentials; DNS, TLS, and `5xx` errors are separate problems. Never publish `gh auth token`, `gh auth status --show-token`, `hosts.yml`, raw secrets, or verbose HTTP traces. Multiple tokens for one user do not supply independent personal API quotas; see [GitHub REST rate limits](https://docs.github.com/en/rest/using-the-rest-api/rate-limits-for-the-rest-api).

### Sign in or recover

Only after confirming that authentication is needed, use HTTPS Git transport and include the `workflow` scope if editing GitHub Actions workflows:

```sh
gh auth login -h github.com -p https -s workflow
gh api /user --jq .login
```

For an existing login needing a scope change or reauthorization, use `gh auth refresh -h github.com -s workflow`, then verify `/user`. That command does **not** guarantee an automatically rotating OAuth refresh token. Do not reauthenticate all running sandboxes in a loop, attempt `offline_access` as a workaround, or reauthenticate on container startup. A revoked token may require a new authorization. For headless device login, enter the CLI's code in the host browser at <https://github.com/login/device>; an `xdg-open` failure alone does not mean the device authorization failed. See [login](https://cli.github.com/manual/gh_auth_login), [refresh](https://cli.github.com/manual/gh_auth_refresh), and [token expiration and revocation](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/token-expiration-and-revocation).

### Shared authentication: explicit trust trade-off

For the published image, trusted projects may opt to replace each project-specific `-gh` mount in a manual command with:

```sh
--mount "type=volume,src=dev-agent-shared-gh,dst=/home/user/.config/gh"
```

Authenticate once from a container using that volume. Do not mount the host's GitHub credentials or share the volume with less-trusted sandboxes: all agents using it receive the same permissions and can change the saved login. Avoid concurrent `gh auth login`, `refresh`, and `logout` against the same volume. Sharing does not create independent API quotas or import existing per-project logins. Sharing a trial's *whole home* is not equivalent to sharing only `gh` configuration. Neither layout fixes token expiry or API contention. Changing mounts requires recreating a named container after safeguarding its other volumes and workspace.

## Docker-in-Docker

Set `DEV_DIND=1` with either launcher for a **nested Docker daemon**, never the host's socket. The outer container becomes `--privileged`: rootless Podman confines it within the invoking user's user namespace, whereas rootful Docker's privileged mode grants broad host-level capabilities and substantially reduces isolation. Do **not** pass `/var/run/docker.sock`, `/run/docker.sock`, or the host Podman socket into the sandbox. The entrypoint refuses an existing non-removable socket mount.

```sh
# Nested Docker, retained through stop/start but not container removal:
DEV_DIND=1 run-dev-podman.sh

# Nested Docker images/data retained through outer-container recreation:
DEV_DIND=1 DEV_DIND_PERSIST=1 run-dev-podman.sh
```

Use `run-dev-docker.sh` for the Docker engine. For manual commands, add `--privileged --env DEV_DIND=1`, and optionally `--mount "type=volume,src=dev-agent-${name}-docker,dst=/var/lib/docker"`. That extra volume is **not necessary for ordinary nested Docker**. Without it, `/var/lib/docker` survives stop/start of the same outer container and is discarded on removal/recreation. A `--tmpfs` mount would instead be stop-volatile, but requires storage-driver and size testing. Home and workspace volumes do not store nested daemon data. Preserve the proper legacy or trial agent/home mounts independently of the nested Docker setting.

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

This checks the nested build, image store, and runtime without accessing a registry.

## Local AI and host Ollama

The container can use a host Ollama server without embedding its daemon or model files. The entrypoint seeds `~/.config/opencode/opencode.json` only when absent, defaulting to `ollama/qwen2.5-coder:7b` at `http://host.docker.internal:11434/v1`. Normal startup preserves existing OpenCode settings; a changed trial seed can overlay matching configuration files. Back up custom agent settings and third-party credentials before trial seed upgrades.

On the host, pull the model and expose Ollama on the bridge:

```sh
ollama pull qwen2.5-coder:7b
OLLAMA_HOST=0.0.0.0:11434 ollama serve
```

For systemd-managed Ollama, set `Environment="OLLAMA_HOST=0.0.0.0:11434"` under `[Service]` in a service override, then `sudo systemctl daemon-reload && sudo systemctl restart ollama`. Listening on `0.0.0.0` exposes port 11434 on host interfaces; restrict it with firewall rules appropriate to your trusted local network. The local Ollama server has no API-key requirement by default.

Podman normally supplies `host.docker.internal` and `host.containers.internal`; Docker Desktop supplies the former. On **native Linux Docker**, set `DEV_DOCKER_HOST_GATEWAY=1` when creating a new container or add `--add-host host.docker.internal:host-gateway` to a manual `docker run` for either image. Do not add this flag inside the container or when starting an existing one.

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

The OpenCode `tools` setting is a top-level map, not a model-level `"tools": true` boolean; keep the defaults. If local-model tool calls are unreliable, review the Ollama context window before changing tool settings.

### Optional additional agents

These agents are **not baked into the base image**. Install only where needed. In the trial, place user-space installs under home to retain them through container recreation; installs in the container system layer are lost on removal. Prefer isolated Python installs over system-wide `pip`.

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

The primary image is based on `debian:${DEBIAN_RELEASE}-slim` (default `stable`) and uses UID/GID `1000:1000`, `zsh`, and passwordless `sudo`. The primary Dockerfile accepts `USER_NAME`, `USER_UID`, and `USER_GID`; the launchers assume the default IDs. It installs tools before applying chezmoi so rendered editor, pager, and credential-helper settings can detect those tools.

Tooling includes Git, Git LFS, `git-credential-oauth`, `gh`, `glab`, zsh, fish, tmux, vim/Neovim, less, `git-delta`, kdiff3, ripgrep, fd, jq, ShellCheck, shfmt, clang, CMake, Ninja, Go, Node.js, Python, Java/Maven, Flutter, Docker CLI/daemon, Buildx, and Compose. Agent CLIs include Codex, Antigravity (`agy`), Mini SWE Agent (`mini`), OpenCode, Claude Code, GitHub Copilot CLI, and Qwen. `difftastic`, `zellij`, and desktop Hyprland/KDE tools are not installed. Jules CLI is intentionally omitted because its installer previously introduced layer ownership incompatible with ordinary rootless Podman subordinate-ID mapping; the primary Dockerfile retains a disabled ownership-normalization recipe.

From the repository root:

```sh
sh containers/dev-dotfiles-debian/test-home-volume.sh
sh containers/dev-dotfiles-debian/test-launchers.sh
```

The home-volume test checks first initialization, same-version restart, updated seed preservation, independent workspace, and failed-upgrade retry. The launcher test mocks both engines to verify published-image defaults, compatible per-project mounts, opt-in trial mounts, missing-image pull/error handling, and safe stopped-container resume. Its own workflow runs on relevant PRs and default-branch changes. Actual rootless Podman/Docker lifecycle, mount ownership across host setups, nested Docker, and volume migrations still require live verification before replacing sandboxes or deleting original volumes. Keep these instructions aligned with the **published image and implemented scripts**, not a merely merged prototype.
