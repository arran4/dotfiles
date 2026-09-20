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
| `ghcr.io/arran4/dev-dotfiles-debian:latest` | Published original image | Separate `-codex`, `-agy`, `-gh`, and `-glab` volumes; use `DEV_FORGE_VOLUME_INIT=1` and, for a named workspace volume, `DEV_VOLUME_INIT=1`. |
| `dev-dotfiles-home-volume:trial` | **Build locally** with `Dockerfile.home-volume` | An optional single, versioned `/home/user` volume, independent `/workspace`, and `DEV_HOME_VOLUME_INIT=1`. Both Linux launcher scripts target this image by default. |

[PR #464](https://github.com/arran4/dotfiles/pull/464) merged the *opt-in trial implementation* into the repository; it did **not** make the locally built trial image the published `:latest` image. Do not mix the two images' mount layouts or pass `DEV_HOME_VOLUME_INIT=1` to the published tag. No existing legacy volumes are migrated automatically. Check the actual published image and its release workflow before changing these instructions when publication changes.

## Start a project sandbox

From the **dotfiles repository root**, build the project-home trial image with the engine you intend to use:

```sh
podman build -f containers/dev-dotfiles-debian/Dockerfile.home-volume \
  --build-arg BASE_IMAGE=ghcr.io/arran4/dev-dotfiles-debian:latest \
  --build-arg IMAGE_VERSION=home-volume-trial-1 \
  -t dev-dotfiles-home-volume:trial .
```

For Docker, substitute `docker build` for `podman build`. `BASE_IMAGE` may point to a locally built primary image. On a subsequent seed release, change `IMAGE_VERSION` (prefer a real release or commit identifier); the archive digest is also included in the stored seed version. The trial currently derives from the original image and therefore does not remove its baked-home layers.

The Linux-only launchers are chezmoi-managed source files [`../../dot_local/bin/executable_run-dev-podman.sh`](../../dot_local/bin/executable_run-dev-podman.sh) and [`../../dot_local/bin/executable_run-dev-docker.sh`](../../dot_local/bin/executable_run-dev-docker.sh). Apply these dotfiles with chezmoi: they install as `~/.local/bin/run-dev-podman.sh` and `~/.local/bin/run-dev-docker.sh`. Ensure `~/.local/bin` is on `PATH`; then run the appropriate command **from the host project directory**, not the dotfiles directory:

```sh
cd ~/Documents/Projects/my-project
run-dev-podman.sh
# Or, if the image was built with Docker:
run-dev-docker.sh
```

If you have not applied chezmoi yet, invoke the launcher by its absolute path inside your dotfiles checkout while your current directory is the target project. The default launcher bind-mounts this checkout at `/workspace`, mounts a project-scoped named volume at `/home/user`, and gives the container a stable name. It never uses `--rm`, passes through the host Docker socket, or mounts host credentials. Use distinct sandbox names when testing the trial alongside a legacy sandbox.

On a later invocation, a stopped named container is **resumed**, not rebuilt; if already running, the launcher prints an `exec` command for an additional shell. To resume manually use `podman start -ai --detach-keys='' dev-agent-<name>-trial` or `docker start -ai dev-agent-<name>-trial`. A resumed container retains its previous image and mount settings even if you changed the launcher environment or rebuilt the tag. See [Storage, upgrades, and migration](#storage-upgrades-and-migration) before removing it.

### Launcher settings

Set these environment variables on the invocation (for example `SANDBOX_NAME=my-project DEV_WORKSPACE_MODE=volume run-dev-podman.sh`):

| Setting | Default | Effect |
| --- | --- | --- |
| `SANDBOX_NAME` | Current directory basename | Normalized, lowercase per-project name for the container and volumes. |
| `DEV_IMAGE` | `dev-dotfiles-home-volume:trial` | Already-built project-home image in the selected engine; the launchers reject the published legacy tag. |
| `DEV_WORKSPACE_MODE` | `bind` | `bind` = current host checkout; `volume` = separate persistent `-workspace` volume; `container` = writable layer only. |
| `DEV_HOME_MODE` | `volume` | `volume` = persistent `-home` volume; `container` = writable layer only. |
| `DEV_DIND` | `0` | `1` enables a privileged **nested** Docker daemon, not the host Docker daemon. |
| `DEV_DIND_PERSIST` | `0` | With `DEV_DIND=1`, `1` also mounts a separate persistent `-docker` volume at `/var/lib/docker`. |
| `DEV_DOCKER_HOST_GATEWAY` | `0` | Docker launcher only: `1` adds native Linux's `host.docker.internal:host-gateway` mapping for host Ollama. |

A disconnected but persistent checkout uses `DEV_WORKSPACE_MODE=volume`; a fully disposable sandbox uses `DEV_HOME_MODE=container DEV_WORKSPACE_MODE=container`. Use `SANDBOX_NAME` for a stable, distinct project identity. Neither launcher accepts positional arguments; use these variables for configuration. The Podman script uses rootless `--userns=keep-id:uid=1000,gid=1000`; the Docker script does not support that Podman-only flag. Check bind-mount permissions for the image's default UID/GID `1000:1000`, especially with rootless Docker.

## Manual Docker and Podman commands

The launchers above are the preferred ordinary workflow. These multiline examples remain for manual customization and for understanding the actual mounts. Set `name` to a unique Docker/Podman-safe project name first; run from the host checkout you intend to edit.

### Project-home trial: Podman

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

### Project-home trial: Docker

```sh
name=my-project
workspace=$(pwd -P)
docker run -it --name "dev-agent-${name}-trial" --restart=no \
  --hostname "agent-sandbox-${name}" --env DEV_HOME_VOLUME_INIT=1 \
  --workdir /workspace \
  --mount "type=bind,src=${workspace},dst=/workspace,rw" \
  --mount "type=volume,src=dev-agent-${name}-home,dst=/home/user" \
  dev-dotfiles-home-volume:trial
```

For either engine, replace the workspace bind mount with `--mount "type=volume,src=dev-agent-${name}-workspace,dst=/workspace"` and set `DEV_VOLUME_INIT=1` for a separate persistent workspace. Omit the workspace mount to clone or import a repository into the container's writable `/workspace`, including a bare repository. Omit *both* mounts for a fully disposable experiment, but retain `DEV_HOME_VOLUME_INIT=1` for the trial's writable home. Do not use `--rm` if any needed data lives only in the container writable layer. `/workspace` is a real independent directory, never a symlink into home; `~/workspace` may be a convenience link **to** it. The initializer does not seed or modify `/workspace`.

### Currently published image: legacy mounts

The published `ghcr.io/arran4/dev-dotfiles-debian:latest` still uses the four separate agent and forge volumes; **do not** use the trial launcher or its `DEV_HOME_VOLUME_INIT` flag with it. Use this Podman command from your host project checkout:

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

For Docker, substitute `docker run`, omit `--userns=keep-id:uid=1000,gid=1000`, and verify the checkout's UID/GID permissions. For a legacy named workspace, replace its bind mount with `--mount "type=volume,src=dev-agent-${name}-workspace,dst=/workspace"` and add `--env DEV_VOLUME_INIT=1`. Keep old volumes until intentional migration has been verified.

## Storage, upgrades, and migration

| Path | Lifetime and purpose |
| --- | --- |
| `/home/user` | Trial project's persistent `-home` volume by default; holds dotfiles, CLI configurations, authentication, agent data, and history. Without its mount, it belongs to the container writable layer. |
| `/workspace` | Host bind mount, independent named `-workspace` volume, or container writable layer, **regardless of home mode**. |
| `/var/lib/docker` | When nested Docker is enabled: outer-container writable layer by default; separate `-docker` volume only when requested. |
| `/usr/local/share/dev-dotfiles-debian/home-seed.tar` | Trial's prepared image-home archive outside the runtime home mount. |
| `/usr/local/share/dev-dotfiles-debian/home-seed-version` | Build identifier and archive digest for the trial seed. |
| `~/.dev-dotfiles-seed-version` | Version last successfully applied to this home. |

**Stop versus remove:** Stopping and restarting the *same* container preserves its writable layer, including an unmapped `/workspace` and nested Docker data. Removing/recreating that container discards the writable layer, even when the same image tag is reused. Bind mounts and named volumes have separate lifetimes; removing the container does not remove a named volume unless explicitly requested. A persistent home does not make an unmapped workspace persistent across recreation.

**Home seeding:** `DEV_HOME_VOLUME_INIT=1` initializes the trial home from the image-prepared archive on first start. Reusing the same seed version skips the overlay. When the seed version changes, matching seeded configurations are overlaid; paths absent from the seed are retained, and known shell-history and GitHub/GitLab/Codex/Antigravity auth/session paths are excluded on subsequent upgrades. Other locally modified seeded dotfiles **can be overwritten** and not every application's secret path is covered. The marker only advances after successful extraction. This flag does not verify that the target is a named volume: **never bind-mount your host home to `/home/user`**.

**Upgrade a trial container:** Back up locally edited configurations and any `/workspace` data stored only in the container writable layer. Build the newer image with a changed seed version, stop and remove *only the existing named container object*, then run the launcher again with the **same project name and named volume(s)**. Starting a stopped container does not adopt the rebuilt image. If you changed launcher modes, remember that they apply only when a *new* container is created. Do not delete named volumes just to refresh an image.

**Legacy-to-trial migration:** The old layout uses `-workspace`, `-codex`, `-agy`, `-gh`, and `-glab` volumes. The trial `-home` volume does not import any of them. Stop the legacy container; back up the volumes; copy contents from the old four agent/forge volumes into the corresponding paths within the new trial home with a separate migration container; retain or remount the workspace volume independently. Verify file ownership, repository data and authentication before deleting anything. **Do not nest the old four mounts inside the new home:** they hide files that the seed prepared there. Keyring-backed logins may need reauthentication. Docker and Podman maintain different volume stores; do not assume their volume names refer to the same data.

**Deliberate cleanup:** Identify whether the workspace is a host checkout, a named volume or the container layer before removing a sandbox. Never copy legacy five-volume cleanup commands into a trial cleanup. Delete only the particular containers and volumes you actually intend to discard.

## GitHub CLI authentication

Persistent `gh` configuration in the legacy image is under `/home/user/.config/gh` (usually a per-project `-gh` volume). The trial home contains that path in its per-project `-home` volume. **Persistent credentials do not guarantee a permanently valid token.** Repeated `gh auth login` in separate project containers can create multiple OAuth authorizations and may cause an older authorization to be revoked when GitHub's active-token limits are reached. Several simultaneous agents may also contend for the same account's API rate limit. An `gh auth status` error can be caused by rate limiting or connectivity rather than token revocation; see [GitHub CLI issue #14053](https://github.com/cli/cli/issues/14053).

### Diagnose first; do not expose secrets

Run inside the affected container:

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

`GH_TOKEN` or `GITHUB_TOKEN` in the environment can override the persisted login; correct that source before changing saved credentials. A successful `/user` request establishes that the CLI can authenticate that request even if `gh auth status` reports an error. A `403` or `429` mentioning rate limits warrants reducing calls and observing the reset/retry time, **not** reauthorizing; an HTTP `401` with the intended token is consistent with invalid credentials. DNS, TLS and `5xx` failures are separate problems. Do not post `gh auth token`, `gh auth status --show-token`, `hosts.yml`, raw secrets or verbose HTTP traces in logs or issues. Concurrent agents using multiple tokens for one user do not obtain independent personal API-rate-limit budgets; refer to [GitHub REST rate limits](https://docs.github.com/en/rest/using-the-rest-api/rate-limits-for-the-rest-api).

### Sign in or recover

Only after confirming that authentication is needed, use HTTPS Git transport and include the `workflow` scope if the agent edits GitHub Actions workflows:

```sh
gh auth login -h github.com -p https -s workflow
gh api /user --jq .login
```

For an intended existing login that needs a scope change or reauthorization, run `gh auth refresh -h github.com -s workflow`, then verify `/user` again. `gh auth refresh` is **not** a guarantee that `gh` has stored an auto-rotating OAuth refresh token. Do not add automatic reauthorization on container startup, request `offline_access` as a workaround or reauthenticate all running containers in a loop. An already revoked token cannot be recovered by refreshing it: a new independent authorization may be required. For headless device login, open <https://github.com/login/device> in the **host browser** and enter the CLI's code. A failure to run `xdg-open` alone does not establish that device authorization failed. See [GitHub CLI authentication](https://cli.github.com/manual/gh_auth_login), [refresh](https://cli.github.com/manual/gh_auth_refresh), and [token expiration and revocation](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/token-expiration-and-revocation).

### Shared authentication: explicit trust trade-off

For the **legacy** image only, trusted projects may opt to replace the `-gh` mount in the manual command with one shared volume:

```sh
--mount "type=volume,src=dev-agent-shared-gh,dst=/home/user/.config/gh"
```

Authenticate once from a container using that volume. Do not share the host's GitHub credentials, and do not mount the shared volume into less-trusted sandboxes: all agents using it receive the same GitHub permissions and can modify the stored login. Avoid concurrent `gh auth login`, `refresh` and `logout` against the same volume. This does not create independent API quotas and does not automatically import existing per-project credentials. The **trial's project-home volume is independent per project**; sharing its entire home is not equivalent to sharing just `gh` configuration, and neither design fixes token expiry or API contention. Recreate an existing named container to change its mounts, preserving other volumes and workspace first.

## Docker-in-Docker

Set `DEV_DIND=1` with either trial launcher for a **nested Docker daemon**, never the host's socket. The outer container becomes `--privileged`: rootless Podman confines it within the invoking user's user namespace, whereas rootful Docker's privileged mode grants broad host-level capabilities and substantially weakens isolation. Do **not** pass `/var/run/docker.sock`, `/run/docker.sock` or the host Podman socket into the sandbox. The entrypoint refuses an existing non-removable socket mount.

```sh
# Nested Docker, disposable when the outer container is removed:
DEV_DIND=1 run-dev-podman.sh

# Nested Docker data also survives outer-container recreation:
DEV_DIND=1 DEV_DIND_PERSIST=1 run-dev-podman.sh
```

Use `run-dev-docker.sh` instead if the trial image was built with Docker. For manual commands, add `--privileged --env DEV_DIND=1`; optionally add `--mount "type=volume,src=dev-agent-${name}-docker,dst=/var/lib/docker"` to preserve nested images, build cache, and inner containers across recreation. **That extra volume is not necessary for ordinary nested Docker.** Without it, `/var/lib/docker` lives in the outer container's writable layer: it survives *stop/start* of that same container but is discarded on *remove/recreate*. A `--tmpfs` mount would instead be stop-volatile, but size and storage-driver compatibility need testing; it is not the default. The home volume does not store daemon data.

For the **published legacy image**, add `--privileged --env DEV_DIND=1` to its manual launch command and retain its legacy agent/forge mounts. Nested Docker storage remains independently optional there too. The trial launcher is not a launcher for the published image.

Verify the nested daemon inside the container:

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

This smoke test checks the inner build, image store, and container runtime without pulling from a registry.

## Local AI and host Ollama

The container can use a host Ollama server without embedding the daemon or models. The entrypoint seeds `~/.config/opencode/opencode.json` **only when absent**; its default uses `ollama/qwen2.5-coder:7b` at `http://host.docker.internal:11434/v1`. Existing OpenCode settings are left alone by the normal entrypoint. A trial *image upgrade* can still overlay matching seeded settings; back up any custom agent configuration, including unprotected OpenCode or other third-party-agent credentials, before a seed change.

On the host, pull the model and expose Ollama on the bridge:

```sh
ollama pull qwen2.5-coder:7b
OLLAMA_HOST=0.0.0.0:11434 ollama serve
```

For a systemd-managed Ollama daemon, set `Environment="OLLAMA_HOST=0.0.0.0:11434"` under `[Service]` in a service override, then `sudo systemctl daemon-reload && sudo systemctl restart ollama`. Listening on `0.0.0.0` exposes port 11434 on host interfaces; restrict it using firewall rules appropriate to your trusted local network. Ollama's local server does not require an API key by default.

Podman normally provides `host.docker.internal` and `host.containers.internal`, and Docker Desktop provides the former. On **native Linux Docker**, set `DEV_DOCKER_HOST_GATEWAY=1` when creating a *new trial container* or add `--add-host host.docker.internal:host-gateway` to a manual `docker run` command for either image. Do not add that flag inside the container or to `docker start`.

Inside the container, verify access, then use OpenCode:

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

The OpenCode `tools` setting is a top-level map, not a model-level `"tools": true` boolean; leave the defaults in place. If local-model tool calls are unreliable, review the Ollama context window rather than adding a model-level tools flag.

### Optional additional agents

These agents are **not baked into the base image**. Install them only in sandboxes that need them. In the trial, put user-space installs under home to retain them through container recreation; installs into the container's system writable layer are discarded when the outer container is removed. Prefer isolated Python installs over system-wide `pip`.

**Aider:** `pipx install aider-chat` (or `uv tool install --force --python python3.12 --with pip aider-chat@latest` when appropriate). Point its Ollama transport at the host endpoint **without** `/v1`:

```sh
export OLLAMA_API_BASE=http://host.docker.internal:11434
aider --model ollama_chat/qwen2.5-coder:7b
```

**Zero (`Gitlawb/zero`):** install its standalone release with `curl -fsSL https://raw.githubusercontent.com/Gitlawb/zero/main/scripts/install.sh | bash` only after reviewing the upstream installer. Then configure and verify:

```sh
zero setup ollama \
  --base-url http://host.docker.internal:11434/v1 \
  --model qwen2.5-coder:7b
zero providers list
zero models list
zero doctor
```

**jcode (`1jehuang/jcode`):** install with `curl -fsSL https://jcode.sh/install | bash` only after reviewing the upstream installer, then use a host-local, no-auth OpenAI-compatible profile:

```sh
jcode provider add host-ollama \
  --base-url http://host.docker.internal:11434/v1 \
  --model qwen2.5-coder:7b \
  --no-api-key \
  --set-default
jcode --provider-profile host-ollama auth-test
```

## Installed tools and verification

The primary image is built on `debian:${DEBIAN_RELEASE}-slim` (default `stable`), uses a default `user` with UID/GID `1000:1000`, `zsh`, and passwordless `sudo`. `USER_NAME`, `USER_UID`, and `USER_GID` configure the primary Dockerfile; the trial launchers and examples assume the default UID/GID. The base build installs relevant tools before applying chezmoi so editor, pager, and credential-helper settings see those tools.

Tooling includes Git, Git LFS, `git-credential-oauth`, `gh`, `glab`, zsh, fish, tmux, vim/Neovim, less, `git-delta`, kdiff3, ripgrep, fd, jq, ShellCheck, shfmt, clang, CMake, Ninja, Go, Node.js, Python, Java/Maven, Flutter, Docker CLI/daemon and Buildx/Compose. Agent CLIs include Codex, Antigravity (`agy`), Mini SWE Agent (`mini`), OpenCode, Claude Code, GitHub Copilot CLI and Qwen. `difftastic`, `zellij`, and desktop Hyprland/KDE tooling are absent from this headless image. Jules CLI is intentionally omitted because its installer previously produced layers incompatible with normal rootless Podman subordinate-ID mapping; the primary Dockerfile retains a disabled normalization recipe.

From the repository root, run:

```sh
sh containers/dev-dotfiles-debian/test-home-volume.sh
```

This checks seed initialization, a same-version restart, version change, auth/history preservation, independent workspaces, and retry after failed upgrades. The actual rootless Podman/Docker lifecycle, ownership on all host setups, nested Docker, and volume migrations require additional live verification before replacing existing sandboxes or deleting any original volumes. Keep documentation synchronized with the *implemented image and launch scripts*, not just proposed behaviour.
