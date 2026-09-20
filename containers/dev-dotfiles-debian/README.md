# dev-dotfiles-debian

This directory contains a Debian-based development image with dotfiles, compilers, language toolchains, GitHub/GitLab clients and AI coding agents. It works with Podman and Docker.

**Image status:** `ghcr.io/arran4/dev-dotfiles-debian:latest` is still the published image, using separate volumes for the agent and forge configuration. PR #464 introduces an **opt-in, locally built alternative**, `dev-dotfiles-home-volume:trial`, that consolidates those directories in a versioned project-home volume. The commands for the alternative image below **do not work with published `:latest`** until its Dockerfile and entrypoint are integrated. See [HOME-VOLUME.md](HOME-VOLUME.md) for the complete Podman and Docker command matrix, persistence and migration guidance. No existing volume is migrated automatically.

**Linux launchers:** After building the trial image, install the host commands from [`dot_local/bin/executable_run-dev-podman.sh`](../../dot_local/bin/executable_run-dev-podman.sh) and [`dot_local/bin/executable_run-dev-docker.sh`](../../dot_local/bin/executable_run-dev-docker.sh) by applying this dotfiles branch with chezmoi. Chezmoi removes the `executable_` source prefix, installs them at `~/.local/bin/run-dev-podman.sh` and `~/.local/bin/run-dev-docker.sh`, and sets executable permissions. With `~/.local/bin` on your `PATH`, run `run-dev-podman.sh` or `run-dev-docker.sh` **from the host project directory**. They replace the multiline `run` examples below: the default bind-mounts the current directory at `/workspace`, uses one named home volume and preserves the named container. They also support an independently persistent workspace, no volume mounts and optional nested Docker without a persistent Docker-data volume. See [Linux launch scripts](HOME-VOLUME.md#linux-launch-scripts) for usage, environment overrides, resumption and safe image replacement. These scripts are for the **locally built trial image only**, not the published legacy tag.

## Quick start: the proposed project home

Build the alternative image from the repository root, using the existing published image as a base:

```sh
podman build -f containers/dev-dotfiles-debian/Dockerfile.home-volume \
  --build-arg BASE_IMAGE=ghcr.io/arran4/dev-dotfiles-debian:latest \
  --build-arg IMAGE_VERSION=home-volume-trial-1 \
  -t dev-dotfiles-home-volume:trial .
```

With Docker, replace `podman build` with `docker build`. Use a distinct project/container name from an existing legacy sandbox.

### Podman: host checkout plus one home volume

From the host project directory:

```sh
workspace=$(pwd -P)
name=$(basename "$workspace")
podman run -it --name "dev-agent-${name}-trial" --restart=no \
  --userns=keep-id:uid=1000,gid=1000 \
  --hostname "agent-sandbox-${name}" --env DEV_HOME_VOLUME_INIT=1 \
  --workdir /workspace \
  --mount "type=bind,src=${workspace},dst=/workspace,rw" \
  --mount "type=volume,src=dev-agent-${name}-home,dst=/home/user" \
  dev-dotfiles-home-volume:trial
```

### Docker: host checkout plus one home volume

Use the locally built Docker variant on a Docker setup whose UID/GID matches the image's `1000:1000` user:

```sh
workspace=$(pwd -P)
name=$(basename "$workspace")
docker run -it --name "dev-agent-${name}-trial" --restart=no \
  --hostname "agent-sandbox-${name}" --env DEV_HOME_VOLUME_INIT=1 \
  --workdir /workspace \
  --mount "type=bind,src=${workspace},dst=/workspace,rw" \
  --mount "type=volume,src=dev-agent-${name}-home,dst=/home/user" \
  dev-dotfiles-home-volume:trial
```

Docker does not support Podman's `--userns=keep-id`. Rootless Docker users should check bind-mount permissions rather than copying the Podman flags blindly. On native Linux Docker using host Ollama, add `--add-host host.docker.internal:host-gateway` to `docker run`.

Both examples keep **`/workspace` as an independent real directory**, not a symlink into home. Instead of a host bind mount, you can mount `dev-agent-${name}-workspace` at `/workspace` for an independently persistent, filesystem-disconnected checkout or imported/bare Git repository; that uses **two named volumes**, home and workspace. Without a workspace mount, imports and clones into `/workspace` persist only while the same container object exists. Without either volume, both home and workspace are disposable with the container. See [HOME-VOLUME.md](HOME-VOLUME.md#workspace-modes) for all four launch modes and their exact commands.

Run `gh auth login`, `glab auth login`, `codex` or `agy` inside the container as usual. Agent and forge state is stored in its project home rather than in separate `-codex`, `-agy`, `-gh` and `-glab` volumes; do not add nested mounts for those directories. No host credential or host home-directory bind mount is required.

To stop an attached sandbox, exit its login shell; resume the same stopped container with `podman start -ai dev-agent-${name}-trial` or `docker start -ai dev-agent-${name}-trial` as appropriate. **Starting an existing container does not upgrade its image.** To refresh the versioned home seed, back up any important changes, rebuild the alternative image, stop and remove the old *container object* (not its named volumes), and create a new container with the same home volume name. Persist or export `/workspace` before recreation when it lives only in the old container's writable layer. A changed seed version overlays matching dotfiles while preserving unrelated home files and known auth/history paths; see [HOME-VOLUME.md](HOME-VOLUME.md#paths-and-lifecycle) for limitations and migration.

### Currently published image: legacy volume layout

Until the prototype is integrated and published, `ghcr.io/arran4/dev-dotfiles-debian:latest` still needs the **original** launch flags. For a host checkout in Podman, its persistence mounts are:

```sh
--env DEV_FORGE_VOLUME_INIT=1 \
--mount "type=bind,src=$(pwd -P),dst=/workspace,rw" \
--mount "type=volume,src=dev-agent-${name}-codex,dst=/home/user/.codex" \
--mount "type=volume,src=dev-agent-${name}-agy,dst=/home/user/.gemini" \
--mount "type=volume,src=dev-agent-${name}-gh,dst=/home/user/.config/gh" \
--mount "type=volume,src=dev-agent-${name}-glab,dst=/home/user/.config/glab-cli"
```

For a disconnected project with the published image, use `--env DEV_VOLUME_INIT=1` and add `--mount "type=volume,src=dev-agent-${name}-workspace,dst=/workspace"` instead of the bind mount. These flags are **legacy-only**: do not pass the four separate home-subdirectory mounts to the experimental home-volume image. Keep the old volumes until migration has been verified; the new `-home` volume does not automatically inherit their contents.

## Configuration and tools

The base image is built on `debian:${DEBIAN_RELEASE}-slim` (default `stable`). Its default user is `user`, UID/GID `1000:1000`, with `zsh` and passwordless `sudo`. Build arguments `USER_NAME`, `USER_UID` and `USER_GID` configure the primary Dockerfile; the examples and derived trial image assume the defaults. Rootless Podman is preferred when running agents with unrestricted permissions inside their **outer** container boundary. Avoid broad host mounts and host socket passthrough.

Installed tools include Git, Git LFS, `git-credential-oauth`, `gh`, `glab`, zsh, fish, tmux, vim, Neovim, less, `git-delta`, kdiff3, ripgrep, fd, jq, shellcheck, shfmt, clang, CMake, Ninja, Go, Node.js, Python, Java/Maven, Flutter, Docker CLI/daemon and Buildx/Compose. The build applies the dotfiles with chezmoi only after relevant tools are installed, so capability-dependent editor, pager and OAuth settings are rendered with those tools available. `difftastic`, `zellij` and desktop-only Hyprland/KDE tools are not installed in the headless image.

Agent CLIs include Codex, Antigravity (`agy`), Mini SWE Agent (`mini`), OpenCode, Claude Code, GitHub Copilot CLI and Qwen. Codex's executable is installed outside the runtime home; its auth/config state lives under `~/.codex`. Jules CLI is deliberately omitted because its installer can produce image layers incompatible with normal rootless Podman subordinate-ID mapping. The Dockerfile documents a disabled recipe for normalizing that installer if reinstated.

The base image runs `chezmoi init --apply` at build time. The **trial image** additionally snapshots the resulting prepared home outside the runtime home mount, then initializes or reapplies it on a version change; it does **not** run chezmoi against a project volume on every start. Locally modified seeded dotfiles may be replaced on version changes. Review and back up customizations before changing images. The trial derives from the original image, so it does not yet remove the older image's baked-home layers.

## OpenCode with host Ollama

Start Ollama on the host and pull the default model:

```sh
OLLAMA_HOST=0.0.0.0:11434 ollama serve
ollama pull qwen2.5-coder:7b
```

Once inside either variant, use `opencode --auto`. The entrypoint creates the default `~/.config/opencode/opencode.json` when missing, pointing at `http://host.docker.internal:11434/v1`; native Linux Docker may need the `--add-host` flag shown above. On a trial-image upgrade, the existing OpenCode configuration is in the versioned home and should be reviewed before rebuilding; [LOCAL-AI.md](LOCAL-AI.md) covers host bridging, security and alternative agents.

## Docker-in-Docker and security

Nested Docker is a separate, opt-in mode using `DEV_DIND=1`. By default its daemon stores images, build cache and inner containers under `/var/lib/docker` in the **outer container's writable layer**, not in the home volume. They survive stopping and restarting that outer container but are discarded when it is removed or recreated. A separate Docker-data volume is **optional**, only for retaining nested Docker state across outer-container recreation. Privileged outer containers have additional security implications. Use the appropriate image-specific example in [DIND.md](DIND.md), and never bind mount the host's Docker or Podman socket.

The project-home volume consolidates isolated container credentials, **not host credentials**. Do not mount the host home directory, `.ssh`, desktop keyring, password store, or Docker socket into an unrestricted agent container. Restrict outbound network access when necessary. If passing an API key, pass only the key the selected agent needs. Antigravity's account authentication may require reauthentication where its external keyring state is not portable.

## Verification

From the repository root run `sh containers/dev-dotfiles-debian/test-home-volume.sh` to check initial seed, same-version restart, version changes, auth/history preservation, workspace independence and failed-upgrade retry. The derived image and actual rootless Docker/Podman lifecycle have not been fully validated; do not replace existing sandboxes or delete their volumes solely on the basis of this PR. The experimental image and the legacy published tag remain distinct until the change is deliberately adopted.
