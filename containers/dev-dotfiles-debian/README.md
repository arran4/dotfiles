# Development container (Docker and Podman)

The [Dockerfile](Dockerfile) builds a Debian-based development image with chezmoi-managed dotfiles, CLI tools, coding agents and optional nested container engines.

The image includes the pinned upstream `ast-grep` CLI for amd64 and arm64 (`ast-grep --version`). The deprecated `sg` alias is intentionally omitted because it conflicts with the system utility. Docker and Podman use the **same image**: `ghcr.io/arran4/dev-dotfiles-debian:latest`. This page documents image-specific operation and recovery; start with the [root README](../../README.md) for the personal machine bootstrap.

## Start a project

Install the chezmoi-managed host launchers (or inspect their source in [Podman](../../home/dot_local/bin/executable_run-dev-podman.sh) and [Docker](../../home/dot_local/bin/executable_run-dev-docker.sh)), then run one from the project directory:

```sh
cd ~/Documents/Projects/my-project
run-dev-podman.sh
# Alternatively: run-dev-docker.sh
```

New outer containers are **ephemeral by default**, while the per-project home volume and host checkout persist. The usual image is pulled on **each new launch**: `DEV_PULL_MODE` defaults to `always` for published images and `never` for local builds; `missing` accepts a cached image. A stopped persistent container resumes its original image, regardless of new pulls.

For the full list of supported flags, environment variables, defaults and examples, consult:

```sh
man run-dev-podman.sh
man run-dev-docker.sh
```

Common overrides:

```sh
SANDBOX_NAME=another-project run-dev-podman.sh
DEV_DIND=0 run-dev-podman.sh
DEV_PULL_MODE=missing run-dev-podman.sh
run-dev-podman.sh --persist-container
```

The current project directory is normally bind-mounted at `/workspace`; `DEV_WORKSPACE_MODE=volume` makes it an independent named volume, and `--no-workspace-mount` keeps it in the outer writable layer. For a disposable home use `--no-home-volume`, which requires a seeded image. Docker and Podman have **separate** container and volume stores.

### Build the current image locally

The repository deliberately has one Dockerfile and no separate home-volume trial image:

```sh
podman build --build-context dotfiles=. \
  -f containers/dev-dotfiles-debian/Dockerfile \
  -t dev-dotfiles-local:dev .
DEV_IMAGE=dev-dotfiles-local:dev run-dev-podman.sh
```

Use `docker build` and `run-dev-docker.sh` for Docker. A custom image must have the seeded-home label: `io.github.arran4.dev-dotfiles.home-seed=1`. A published image without that label uses a legacy compatibility layout; an unlabelled custom image is not accepted.

## Image release and update

`:latest` follows the newest stable published image, not every commit merged to `main`. A release also publishes version-specific tags; prereleases do not replace `:latest`. A successful CI run or PR merge alone does not publish an image, and an image cached locally will not update without a pull.

When the repository is unchanged but bundled tools need updating, dispatch a fresh patch release and forced rebuild:

```sh
gh workflow run ci.yml --repo arran4/dotfiles --ref main \
  -f mode=release-patch -f force_release=true
```

This prepares a new version tag, then dispatches `publish-tag` to build and publish the image and release assets. It refreshes unpinned downloads by pulling the base image and rebuilding without cache; explicit Dockerfile pins are still honoured. To recover an existing release, dispatch `publish-tag` on the relevant tag and use `force_release=true` if a rebuild is necessary. Old tags run the workflow revision they contain. Existing tags are never overwritten, and older releases cannot move stable aliases backwards.

To upgrade a **disposable** seeded sandbox: back up important files in its home volume, exit, then rerun the launcher with the same project name to pull the current image. The named home volume remains. To upgrade a **persistent** outer container: first back up writable-layer-only data, stop and remove **only the outer container** (never use `--volumes`), then relaunch. Restarting a retained container cannot change its image, mounts, timezone or privileges. Validate the new home before removing backups.

## Persistence and migration

| Path or resource | Default lifecycle |
| --- | --- |
| Outer `dev-agent-<name>` container | Disposable (`--rm`); retained when `DEV_CONTAINER_PERSIST=1` |
| `/home/user` | Named `dev-agent-<name>-project-home` volume on seeded images |
| `/workspace` | Host checkout bind mount; optionally a named `-workspace` volume |
| Nested `/var/lib/docker` | Outer writable layer; `-docker` volume only with `DEV_DIND_PERSIST=1` |
| Nested Podman data | Optional `-podman` volume with `DEV_PODMAN_PERSIST=1` |
| `/usr/local/share/dev-dotfiles-debian/home-seed.tar` | Prepared home archive in the image, outside the mounted home |
| `~/.dev-dotfiles-seed-version` | Last successfully applied seed version for the current home |

The Dockerfile applies chezmoi when building and archives the prepared home separately. For a new seeded volume, `DEV_HOME_VOLUME_INIT=1` initializes it; later image versions overlay matching seeded files. An unchanged seed is a no-op, and absent files are not removed. Known Codex, Antigravity, GitHub/GitLab session files and shell history are excluded from seed upgrades, but **other locally edited dotfiles or secrets could be overwritten**. The marker only advances after successful extraction. The initializer cannot verify that `/home/user` is a safe named volume: **never mount the host home there**.

### Older sandboxes

Historical published images without a home seed use four separate agent/auth volumes (`-codex`, `-agy`, `-gh`, `-glab`) rather than a whole-home volume. The new layout **does not import them automatically**. Back up the old container writable layer and each volume, create a distinct seeded sandbox with a different `SANDBOX_NAME` when appropriate, and selectively transfer credentials and configurations with a separate migration container. Verify ownership and login before deleting any old storage. Do not overlay the old agent mounts on the new whole-home mount; this hides seeded files.

Earlier outer containers named `dev-agent-<name>-home` need an explicit rename to `dev-agent-<name>` before reuse, provided that destination name is free:

```sh
podman rename dev-agent-my-project-home dev-agent-my-project
# Or: docker rename dev-agent-my-project-home dev-agent-my-project
```

The current launchers intentionally refuse to rename, overwrite or delete old containers automatically; stopped named containers can contain the only copy of writable-layer state. The `-project-home` volume is unchanged by a rename. The old `-trial` containers and `-home` trial volumes are likewise not cleaned automatically. `DEV_NEW_HOME=1` does not override an existing container-name conflict. Never delete an old volume until the new environment is verified.

## Security and nested engines

Both launchers default to `DEV_DIND=1` (Docker-in-Docker with a private daemon), which makes the **outer container privileged**. Rootless host Podman constrains that privilege differently from rootful Docker; neither should be treated as an untrusted-code isolation boundary without reviewing privileges and mounts. Use `DEV_DIND=0` when Docker-in-Docker is unnecessary.

Nested rootless Podman defaults to `DEV_PODMAN_SECURITY=nested`, requiring host `/dev/fuse`. `unconfined` relaxes AppArmor; `privileged` broadens access; `off` removes nested-Podman setup. No launcher mounts the host Docker or Podman daemon socket. **Do not mount the host credential directories or container-engine sockets into an unrestricted agent environment.**

With DIND enabled, `DEV_DIND_PERSIST=1` retains its images in a separate named `-docker` volume; otherwise its image store disappears with a disposable outer container. A local smoke check for the nested daemon is `docker info` inside the running sandbox. Launcher startup also reports effective engine settings and versions. Changes to creation-time permissions require recreating a persistent outer container.

## Authentication

Each seeded project home stores GitHub CLI configuration under `~/.config/gh`. Historical images use the separate `-gh` volume. Prefer one credential model for each sandbox:

```sh
# Interactive web/device login
gh auth login -h github.com -w -p https
gh api /user --jq .login

# Or inject GH_TOKEN / GITHUB_TOKEN in the container's environment
# (do not echo them or commit them)
```

Environment tokens override stored web/device credentials, with `GH_TOKEN` taking precedence over `GITHUB_TOKEN`. For an existing stored OAuth login that requires additional scope, `gh auth refresh -h github.com -s workflow` is supported; it does not refresh environment tokens.

To diagnose without exposing credentials:

```sh
gh api /user --jq .login
gh api /rate_limit --jq '{core: .resources.core, graphql: .resources.graphql}'
gh auth status -h github.com --json hosts
```

A failed `gh auth status` is not itself proof that credentials expired. Distinguish 401 from rate limits (403/429), DNS/TLS and upstream failures. Avoid unnecessary reauthorization across many project homes. Do not print `gh auth token`, `hosts.yml` or raw HTTP traces. Shared auth volumes expose the same permissions to all participating agents; sharing the whole seeded home is more intrusive still. See [GitHub CLI authentication](https://cli.github.com/manual/gh_auth_login) and [environment tokens](https://cli.github.com/manual/gh_help_environment).

## Coding agents and local AI

The image includes Codex, Antigravity (`agy`), OpenCode, Claude Code, GitHub Copilot CLI, Qwen and Mini SWE Agent, plus common CLI build tools (Go, Java, Python, Node, Flutter, Git, `gh`, `glab`, tmux, Vim/Neovim, Podman, Docker, ShellCheck and more). Hyprland/KDE desktop tools, `difftastic` and `zellij` are not part of the image.

**Codex:** A fresh image-seeded `~/.codex/config.toml` sets model `gpt-6.1-sol` at high reasoning effort with `approval_policy = "never"` and `sandbox_mode = "danger-full-access"`. That disables the inner approval/sandbox mechanisms: **the outer container's trust boundary and mount choices matter**. The TUI defaults to normal scrollback (`alternate_screen = "never"`) and raw transcript output; modify `~/.codex/config.toml` or use `/raw` if desired. Existing user config is preserved on initial skeleton creation; seed updates have the caveats above.

**Antigravity:** The container stores its settings under `~/.gemini/antigravity-cli/`, not the former `~/.codex/antigravity-cli/`. A guarded entrypoint migration moves only eligible settings, onboarding and OAuth files when destinations are missing; it rejects symlinks and preserves conflicting state for manual inspection. Defaults for fresh homes are supplied from `skel/.gemini/antigravity-cli/`. Recreating an outer container with a new image (not restarting an old one) runs the updated migration. Don't delete either agent home wholesale.

**Host Ollama:** OpenCode is seeded for `ollama/qwen2.5-coder:7b` at `http://host.docker.internal:11434/v1` when its config is missing. On the host:

```sh
ollama pull qwen2.5-coder:7b
OLLAMA_HOST=0.0.0.0:11434 ollama serve
```

Binding `0.0.0.0` exposes the service on host interfaces: restrict port 11434 to trusted networks. Native Linux Docker needs `DEV_DOCKER_HOST_GATEWAY=1` at container creation; Podman and Docker Desktop commonly provide the host alias already. Inside:

```sh
getent hosts host.docker.internal
curl -fsS http://host.docker.internal:11434/v1/models | jq .
opencode --auto
```

### Image-managed agent skills, plugins and browser

`agent-skills/<name>/SKILL.md` remains the source for standalone Codex and Antigravity skills. Codex receives image-owned skills under `/etc/codex/skills`; Antigravity syncs them to `~/.gemini/antigravity-cli/skills` without overwriting modified or unrelated user skills. Removed ordinary image skills are not automatically deleted from persistent homes. Updating Codex's image-owned skills requires a new image; inspect `/skills` inside a running agent, not just the filesystem.

`agent-plugins/arran4-gosubc/` is the first portable Agent Plugins v1 package, with `plugin.json` and `skills/gosubc/SKILL.md`. Antigravity App, CLI and IDE support native plugins: the entrypoint synchronizes image-owned packages to `~/.gemini/config/plugins/` while preserving manually installed or edited plugins. Codex still receives the identical `gosubc` skill in `/etc/codex/skills/gosubc`. No separate MCP service or privilege is introduced by this skill-only plugin.

On the first updated image launch, the sync removes the former `~/.gemini/antigravity-cli/skills/gosubc` only when its contents still match the hash of an image-managed copy **and** the new native plugin has been installed unchanged. Edited, symlinked or user-owned legacy skills are preserved; inspect them manually if `gosubc` appears twice. Other skills remain on their existing paths.

Validate the plugin with `agy plugin validate --strict containers/dev-dotfiles-debian/agent-plugins/arran4-gosubc` from a checkout with `agy` installed; inspect installation using `agy plugin list --json`. On a host without the managed image, `agy plugin install /path/to/arran4-gosubc` is also supported. Offline CI tests check manifest/layout and update safety; image builds additionally run `agy plugin validate --strict` for each bundled package using the installed Antigravity CLI. See the [Antigravity plugin documentation](https://antigravity.google/docs/build-plugins) and [Agent Plugins v1 specification](https://agent-plugins.org/specification).

The image also ships `playwright-cli` with a shared headless Chromium shell, intended for automation. Headed operation needs additional GUI support. The smoke test verifies a local fixture without requiring a public website.

### Additional project CLIs

The image installs Go-built `gosubc`, `g2`, `header`, and `rntocase` at their latest published module versions, with `GOBIN=/usr/local/bin` and `GOTOOLCHAIN=auto`. This is intentionally not reproducibly pinned: `@latest` may change between builds and lag source branches. The Dockerfile logs resolved build information.

`txtar` is built from the latest main-branch source instead, because its current module path does not match the public GitHub import path. It records the Git revision and runs a smoke test for archive commands. These installed executables are distinct from agent skills.

## Verification

From the repository root:

```sh
sh containers/dev-dotfiles-debian/test-home-volume.sh
sh containers/dev-dotfiles-debian/test-launchers.sh
sh containers/dev-dotfiles-debian/test-agent-skills.sh
sh containers/dev-dotfiles-debian/test-agent-plugins.sh
sh containers/dev-dotfiles-debian/test-release-clis.sh
sh containers/dev-dotfiles-debian/test-txtar.sh
sh containers/dev-dotfiles-debian/test-playwright.sh
sh -n home/dot_local/bin/executable_run-dev-podman.sh
sh -n home/dot_local/bin/executable_run-dev-docker.sh
```

These scripts exercise seeded homes, lifecycle decisions, agent skills, installed CLIs and browser setup. They are not a substitute for live host engine, credential and upgrade tests. In particular, check mounts, UID/GID 1000:1000, DIND security, auth survival and published-image labels before destroying or replacing an existing sandbox.
