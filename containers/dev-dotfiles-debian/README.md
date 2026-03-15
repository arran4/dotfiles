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
- Gemini CLI (`gemini-cli`)
- Codex CLI (`codex-cli`)
- Mini SWE Agent (`mini-swe-agent`)
- Jules (`@google/jules`)
- OpenCode AI (`opencode-ai`)
- Claude Code (`@anthropic-ai/claude-code`)
- GitHub Copilot CLI (`@githubnext/github-copilot-cli`)
- QwenChat (`qwenchat`)

## Dotfiles Integration

During the image build process, the dotfiles from this repository are copied into the container. `chezmoi` is installed and automatically applies these dotfiles to the home directory of the configured user, ensuring the environment is immediately ready for use with all custom configurations and aliases in place.
