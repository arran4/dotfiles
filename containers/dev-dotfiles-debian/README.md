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
  --pull=always \
  --userns=keep-id:uid=1000,gid=1000 \
  --hostname agent-sandbox \
  --workdir /workspace \
  --mount type=bind,src="$PWD",dst=/workspace,rw \
  --mount type=volume,src=dev-agent-codex,dst=/home/user/.codex \
  --mount type=volume,src=dev-agent-agy,dst=/home/user/.gemini \
  --mount type=bind,src="$HOME/.config/gh",dst=/home/user/.config/gh,ro \
  --mount type=bind,src="$HOME/.config/glab-cli",dst=/home/user/.config/glab-cli,ro \
  ghcr.io/arran4/dev-dotfiles-debian:latest
```

### Persistent, filesystem-disconnected sandbox

A persistent sandbox does not need this repository, a launcher script, or an existing source checkout on the host. It only needs Docker or Podman and the published image. Give the container and volumes a stable name such as `goa4web`.

#### Podman

Create and attach the sandbox for the first time:

```sh
podman run -it \
  --pull=always \
  --name dev-agent-goa4web \
  --restart=no \
  --detach-keys="" \
  --userns=keep-id:uid=1000,gid=1000 \
  --env DEV_VOLUME_INIT=1 \
  --workdir /workspace \
  --mount type=volume,src=dev-agent-goa4web-workspace,dst=/workspace \
  --mount type=volume,src=dev-agent-goa4web-codex,dst=/home/user/.codex \
  --mount type=volume,src=dev-agent-goa4web-agy,dst=/home/user/.gemini \
  --mount type=volume,src=dev-agent-goa4web-gh,dst=/home/user/.config/gh \
  --mount type=volume,src=dev-agent-goa4web-glab,dst=/home/user/.config/glab-cli \
  ghcr.io/arran4/dev-dotfiles-debian:latest
```

The empty `--detach-keys` disables Podman's interactive detach sequence for this container. Exiting the login shell therefore stops the container rather than leaving it running in the background.

Resume the same stopped container later:

```sh
podman start -ai --detach-keys="" dev-agent-goa4web
```

#### Docker

Create and attach the Docker equivalent:

```sh
docker run -it \
  --pull=always \
  --name dev-agent-goa4web \
  --restart=no \
  --env DEV_VOLUME_INIT=1 \
  --workdir /workspace \
  --mount type=volume,src=dev-agent-goa4web-workspace,dst=/workspace \
  --mount type=volume,src=dev-agent-goa4web-codex,dst=/home/user/.codex \
  --mount type=volume,src=dev-agent-goa4web-agy,dst=/home/user/.gemini \
  --mount type=volume,src=dev-agent-goa4web-gh,dst=/home/user/.config/gh \
  --mount type=volume,src=dev-agent-goa4web-glab,dst=/home/user/.config/glab-cli \
  ghcr.io/arran4/dev-dotfiles-debian:latest
```

Resume it later with:

```sh
docker start -ai dev-agent-goa4web
```

The image entrypoint handles the one engine-dependent detail that should not have to live in a host script. When `DEV_VOLUME_INIT=1` is set, it fixes ownership of only the named-volume mount-point roots and then `exec`s the normal login `zsh`. It does not recursively change the checked-out repository. Volume initialisation is opt-in so the existing bind-mounted workflow can never change ownership of a host checkout or host credential directory.

The login `zsh` is the container's primary process. In ordinary attached use, exiting it stops the container; the stopped container object and all named volumes remain. `--restart=no` prevents a daemon or host restart from automatically starting the sandbox. Docker and Podman also support deliberately detaching from an interactive container; doing so intentionally leaves its shell running, so this workflow is intended to be ended with `exit`, not detach.

Authenticate and check out repositories from inside the sandbox:

```sh
gh auth login
gh repo clone arran4/goa4web
```

or:

```sh
glab auth login
glab repo clone GROUP/PROJECT
```

Multiple repositories can live under `/workspace`; the sandbox name is an isolation name and does not have to match a repository. Network access remains enabled so `gh`, `glab`, `git` and the agents can reach their services. "Disconnected" here means disconnected from the host filesystem.

Removing the container does not remove its named volumes, so an accidentally removed container does not itself discard the checked-out repository or CLI/agent state. To intentionally destroy the complete `goa4web` sandbox, remove the container and then its volumes:

```sh
podman rm -f dev-agent-goa4web
podman volume rm \
  dev-agent-goa4web-workspace \
  dev-agent-goa4web-codex \
  dev-agent-goa4web-agy \
  dev-agent-goa4web-gh \
  dev-agent-goa4web-glab
```

Use the same commands with `docker` instead of `podman` for a Docker sandbox.

GNU Readline is not required for this flow. The image uses `zsh`, whose interactive line editor is ZLE. The stopped named container preserves its writable container filesystem across later `start -ai` invocations, while the named volumes preserve the project and CLI/agent state independently of the container object.

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
