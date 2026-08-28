# dev-dotfiles-debian

This directory contains the Dockerfile for the `dev-dotfiles-debian` container. It serves as a comprehensive, self-contained development environment based on Debian slim, pre-configured with a variety of development tools, languages, and AI assistants.

## Base Image

The container is built on top of `debian:${DEBIAN_RELEASE}-slim` (defaulting to the `stable` release).

## Configuration

By default, the container is configured with a non-root user that has passwordless `sudo` privileges:

- **User:** `user` (configurable via `USER_NAME`)
- **UID:** `1000` (configurable via `USER_UID`)
- **GID:** `1000` (configurable via `USER_GID`)
- **Shell:** `zsh`

This is intentional for agent use: Codex or Antigravity can be given unrestricted permissions inside the container and can use `sudo` to install packages or modify the container filesystem without receiving host root privileges when the image is run with a rootless container engine.

## Pre-installed Tools

The environment comes pre-installed with a wide array of tools to support various development workflows:

### Core Development Tools & Utilities
- **Version Control & Forges:** `git`, GitHub CLI (`gh`), GitLab CLI (`glab`)
- **Shell & Terminal:** `zsh`, `tmux`, `fzf`, `htop`, `tree`
- **Editors & Diff:** `vim`, `kdiff3`, `diffutils`
- **Search & Navigation:** `ripgrep`, `fd-find`
- **Build & C/C++:** `build-essential`, `clang`, `clang-format`, `cmake`, `ninja-build`, `make`, `autoconf`, `automake`, `libtool`, `pkg-config`, `gdb`, `lldb`
- **Web & Misc:** `curl`, `wget`, `jq`, `unzip`, `hugo`, `sqlite3`

### Languages & Frameworks
- **Python:** `python3`, `python3-pip`, `python3-venv`
- **Go:** `golang`
- **Java:** `default-jdk`
- **Node.js:** `nodejs`, `npm`
- **Flutter:** Installed from the `stable` channel to `/opt/flutter`

### AI Assistants & Agents
The container is equipped with several AI-powered CLI tools and agents:
- OpenAI Codex CLI (`codex`), installed with the official standalone installer
- Google Antigravity CLI (`agy`), installed with the official installer
- Mini SWE Agent (`mini-swe-agent`)
- OpenCode AI (`opencode-ai`)
- Claude Code (`@anthropic-ai/claude-code`)
- GitHub Copilot CLI (`@githubnext/github-copilot-cli`)
- QwenChat (`qwenchat`)

Jules CLI is intentionally not installed. Its npm installer can preserve high UID/GID values from its downloaded payload, which can make the published image impossible for normal rootless Podman subordinate-ID mappings to unpack. The Dockerfile retains a commented installation recipe that normalizes the Jules payload to `root:root` if it is re-enabled later.

Codex is installed under `/opt/codex` with its executable exposed in `/usr/local/bin`. Its runtime `~/.codex` directory therefore remains separate and can safely be persisted as a container volume.

## Recommended full-access agent sandbox

Use the container itself as the security boundary and run the agent without its inner command sandbox or approval prompts. Rootless Podman is preferred because container root remains inside an unprivileged user namespace on the host.

From the repository that the agent should be allowed to modify:

```sh
podman run --rm -it \
  --userns=keep-id:uid=1000,gid=1000 \
  --hostname agent-sandbox \
  --workdir /workspace \
  --mount type=bind,src="$PWD",dst=/workspace,rw \
  --mount type=volume,src=dev-agent-codex,dst=/home/user/.codex \
  --mount type=volume,src=dev-agent-agy,dst=/home/user/.gemini \
  ghcr.io/arran4/dev-dotfiles-debian:latest
```

Then run either agent inside the container:

```sh
codex --dangerously-bypass-approvals-and-sandbox
```

```sh
agy --dangerously-skip-permissions
```

This gives the agent unrestricted access to the container and the mounted repository, including passwordless `sudo`, while keeping the rest of the host filesystem outside its namespace.

The named volumes retain agent configuration and session state without exposing the host's normal `~/.codex` or `~/.gemini` directories. For API-key authentication, explicitly pass only the credential required by the selected agent, for example `--env OPENAI_API_KEY` or `--env GEMINI_API_KEY`. Antigravity's Google-account authentication uses the operating-system keyring; do not bind the host D-Bus or desktop keyring into an unrestricted agent container merely to reuse host credentials.

### Docker

The same OCI image works with Docker. Prefer Docker's rootless mode if it is configured. The important properties are the same: mount the target repository rather than the whole home directory and do not grant the outer container host-level privileges.

### Boundary rules

Do not add `--privileged`, host PID/network namespaces, broad device access, or the Docker/Podman daemon socket. Do not mount the whole host home directory, SSH directory, password store, or desktop keyring. Any credential intentionally passed into an unrestricted agent container should be scoped as narrowly as practical, especially GitHub or other forge tokens that can mutate remote repositories.

If stronger containment is needed, restrict the outer container's outbound network access rather than re-enabling the agent's inner sandbox. The main goal of this setup is to let the agent behave like a root-capable developer machine inside a disposable boundary, not to make it root-equivalent on the host.

## Dotfiles Integration

During the image build process, the dotfiles from this repository are copied into the container. `chezmoi` is installed and automatically applies these dotfiles to the home directory of the configured user, ensuring the environment is immediately ready for use with all custom configurations and aliases in place.
