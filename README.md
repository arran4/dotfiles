# arran4 dotfiles

My personal [chezmoi](https://www.chezmoi.io/)-managed dotfiles and machine-bootstrap notes. I have been configuring Linux and related systems since roughly **2004**; the public Git repository begins later because I intentionally started a fresh history rather than publish older commits containing private keys or other secrets. The visible Git history is therefore not a complete history of the configuration.

This is primarily a reference for future me, with working examples and some interesting configuration choices for anyone browsing. Some files are old, some are machine-specific, and not every tracked application is part of my current setup.

## Bootstrap

I normally install the programs I want *before* applying the dotfiles: chezmoi templates detect which executables and features are available, so the installed toolchain affects the generated configuration. Use the platform package manager for the initial tools, then:

```sh
chezmoi init arran4
chezmoi diff
chezmoi apply
```

For an unattended install, `chezmoi init --apply arran4` combines the final steps. The source root is `home/` (see `.chezmoiroot`); `home/.chezmoi.toml.tmpl` handles OS-aware prompts and executable discovery, `home/.chezmoitemplates/` shares shell configuration, and `home/.chezmoiscripts/` contains first-run and update hooks. When the configuration template changes, rerun `chezmoi init --apply arran4`.

The [release ZIP](https://github.com/arran4/dotfiles/releases) is a CI-rendered chezmoi archive, **not** a portable replacement for a per-machine init: it may contain configuration values generated on the CI runner. Use the source and chezmoi for a new machine.

### Machine-local configuration

Sensitive and machine-only settings normally stay outside the shared repository unless I intentionally commit them. Chezmoi can generate `~/.gitconfig.local` with the configured user identity; the main Git template also conditionally includes local Git overrides under `~/.config/git/config.local`, `~/.local/share/git/config.local` and `~/.gitconfig.d/config.local`. Keep credentials and individual host details local.

For Hyprland, the Lua configuration loads `local.lua` if present, then checks hostname-derived modules such as `local_desktop2.lua` and `local_x1linux.lua`. Those committed examples contain display configuration; a private local override should not accidentally mask one. SSH identities and other private host configuration are deliberately handled differently. Review template and ignore rules before adding new machine-specific data.

## Applications I reinstall

My Flatpak selections are an install reference, not an exhaustive inventory of what is active today. The existing Flathub command is system-scoped; the separate FlatPark commands below are intentionally per-user. I have not normalised those scopes.

```sh
flatpak install -y flathub app.authpass.AuthPass com.beeper.Beeper com.bitwarden.desktop com.dropbox.Client com.google.Chrome com.rustdesk.RustDesk com.spotify.Client com.valvesoftware.Steam im.fluffychat.Fluffychat im.nheko.Nheko im.riot.Riot io.anytype.anytype io.ente.auth io.github.martinrotter.rssguard io.github.picocrypt.Picocrypt net.mkiol.SpeechNote net.werwolv.ImHex org.kde.drawy org.kde.marknote org.libreoffice.LibreOffice org.localsend.localsend_app org.mozilla.firefox org.mozilla.thunderbird org.signal.Signal
```

FlatPark, added for an explicitly selected Beeper build (not for general dependency resolution):

```sh
flatpak --user remote-add \
  --if-not-exists \
  --no-enumerate \
  --no-use-for-deps \
  flatpark \
  https://dl.flatpark.org/flatpark.flatpakrepo
flatpak --user install flatpark com.automattic.Beeper
```

A per-user Flathub remote may also be needed for FlatPark's runtimes; a system Flathub remote does not automatically serve user-scoped installations. The Flathub `com.beeper.Beeper` and FlatPark `com.automattic.Beeper` recipes are intentionally both recorded pending a choice of preferred package.

### Development tools

I prefer **Zsh** for interactive shells, **tmux** for terminal sessions, Git and Go tooling, with Vim/Neovim configuration retained. Bash and Fish are also configured but are not equivalent personal preferences. A few useful package-manager commands for bootstrapping:

| System | GitHub and GitLab CLIs |
| --- | --- |
| Gentoo | `sudo emerge dev-vcs/gh dev-vcs/glab` |
| Debian/Ubuntu | Install `gh` via [GitHub CLI's packaging instructions](https://github.com/cli/cli/blob/trunk/docs/install_linux.md); `sudo apt install glab` |
| Arch | `sudo pacman -S github-cli glab` |
| macOS | `brew install gh glab` |

Other occasional installs: `go install github.com/golangci/golangci-lint/v2/cmd/golangci-lint@latest` and [Git Credential Manager](https://github.com/git-ecosystem/git-credential-manager). The development image bundles its own tools.

## My development containers

The `run-dev-podman.sh` and `run-dev-docker.sh` launchers use `ghcr.io/arran4/dev-dotfiles-debian:latest`, normally pulling the latest published image and preparing a project-specific home and workspace. Run either launcher from a project directory:

```sh
cd ~/Documents/Projects/example
run-dev-podman.sh
# or: run-dev-docker.sh
```

The outer container is ephemeral by default; named home/workspace volumes can persist between runs. **Docker-in-Docker is enabled by default and causes a privileged outer container.** To omit nested Docker when it is unnecessary, set `DEV_DIND=0`; review the remaining nested-Podman security mode as well. Do not treat this as an isolation boundary for untrusted agents without examining the settings.

See `man run-dev-podman.sh` and `man run-dev-docker.sh` for options and environment variables. The [development container guide](containers/dev-dotfiles-debian/README.md) covers image building, upgrades, auth, persistent volumes and further operating details.

## Useful commands and configurations

Many custom helpers are installed in `~/.local/bin`, with local manuals in `~/.local/share/man/man1`. The command name is the man-page name:

| Command | Purpose |
| --- | --- |
| `gh-pr.sh` | Interactive branch, commit, push and PR flow |
| `gh-release.sh` | Compute and push a release tag; GitHub Actions does the publishing |
| `extract.sh`, `compress.sh` | File archive helpers |
| `copy-song-url.sh`, `songmean.sh` | Playback metadata and sharing/search helpers |
| `whatsmyip.sh` | External IPv4/IPv6 addresses |
| `hypr-cheatsheet`, `hypr-cycle-layout`, `set-wallpaper` | Hyprland desktop helpers |
| `cliphist-daemon.sh`, `codex-notify` | Clipboard and coding-agent hooks |

For detailed usage, e.g.:

```sh
man gh-pr.sh
man gh-release.sh
man run-dev-podman.sh
man hyprland-keys
```

The last command opens the full Hyprland keyboard reference. Quick reminders: `Super+Return` opens a terminal; `Super+G` enters group-management mode; `Super+/` opens the runtime cheatsheet; and `Super+Shift+S` is a conditional Caelestia screenshot binding. The full manual includes fallback and conditional shortcuts. The active bindings are best checked with `hypr-cheatsheet` or `hyprctl binds -j`.

## Notes and history

Caelestia Shell is installed by the system package manager, not an old chezmoi-managed Git checkout under `~/.config/quickshell`; personal settings remain under `~/.config/caelestia`. Inspect Git history if recovering an older checkout. The repository retains examples of earlier tools and OS configurations even where they are no longer current.

The public history does not cover my earlier Linux configuration period: it was restarted to avoid publishing sensitive historical commits. A more detailed chronology can be reconstructed from separate personal historical notes without importing those records into this repository.
