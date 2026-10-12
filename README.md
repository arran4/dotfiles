# arran4 dotfiles

These are my [chezmoi](https://www.chezmoi.io/)-managed dotfiles, built up from configurations I have used since roughly 2004. They include personal and historical choices that may not suit another machine; copy or adapt the pieces you want rather than applying the entire repository without inspecting it.

## Contents

- [Using the dotfiles](#using-the-dotfiles)
- [Containerised development environment](#containerised-development-environment)
- [Development tools](#development-tools)
- [Flatpak applications](#flatpak-applications)
- [Credentials and Git](#credentials-and-git)
- [Desktop and shell notes](#desktop-and-shell-notes)

## Using the dotfiles

Clone the repository and run `./install`, or use chezmoi directly. When chezmoi reports `warning: config file template has changed`, rerun `chezmoi init --apply arran4` to regenerate the configuration from `.chezmoi.toml.tmpl`.

The setup includes shared Bash/Zsh prompts and aliases (`.chezmoitemplates/`), OS-aware templates (`.chezmoi.toml.tmpl`), a Git configuration selecting available editors and credential helpers, tmux and Vim/Neovim settings, Hyprland/Quickshell configurations, and one-time initialization scripts in `.chezmoiscripts/`. `.chezmoiignore` can skip optional executables when their dependencies are missing.

After applying, open a new terminal to check your prompt, aliases, and Git settings. `tmux` demonstrates the multiplexer configuration; inspect `.chezmoitemplates/` to understand the shared templates. Version checks during setup use a PATH derived from `.chezmoi.toml.tmpl` and warn when a configured tool is older than the minimum version or comparison fails.

## Containerised development environment

**Start here:** [`containers/dev-dotfiles-debian/README.md`](containers/dev-dotfiles-debian/README.md) is the *single operational guide* for the Debian coding-agent container. It contains the Docker and Podman commands, local image build, Linux launch scripts, volumes and upgrades, GitHub authentication, Docker-in-Docker, host Ollama, and tests. Container-specific operating instructions are intentionally **not duplicated** in this root README.

The repository currently provides both a published original image, `ghcr.io/arran4/dev-dotfiles-debian:latest`, and a separately built, opt-in project-home image, `dev-dotfiles-home-volume:trial`. The experimental implementation was merged in [PR #464](https://github.com/arran4/dotfiles/pull/464), but the merger did not by itself publish the trial image as `:latest`. Select the image and matching launch instructions using [Choose the right image](containers/dev-dotfiles-debian/README.md#choose-the-right-image). Do not switch an existing sandbox's image or volume layout without following the [storage and migration guidance](containers/dev-dotfiles-debian/README.md#storage-upgrades-and-migration).

On Linux, the repo supplies chezmoi-installed host commands `run-dev-podman.sh` and `run-dev-docker.sh` for the **locally built trial image**. See [Start a project sandbox](containers/dev-dotfiles-debian/README.md#start-a-project-sandbox) for build and invocation, and [Launcher settings](containers/dev-dotfiles-debian/README.md#launcher-settings) for the options. For the published original image, use the [legacy manual command](containers/dev-dotfiles-debian/README.md#currently-published-image-legacy-mounts). Avoid mounting your host home, credentials, or container-engine socket into an unrestricted agent sandbox.

## Development tools

| Platform | Tool | Installation |
| --- | --- | --- |
| Cross-platform | golangci-lint | `go install github.com/golangci/golangci-lint/v2/cmd/golangci-lint@latest` |
| Cross-platform | Git Credential Manager | See [Git Credential Manager](https://github.com/git-ecosystem/git-credential-manager). |
| Cross-platform | CLIProxyAPI | `go install github.com/router-for-me/CLIProxyAPI/v6/cmd/server@latest && mv "$HOME/go/bin/server" "$HOME/.local/bin/CLIProxyAPI"` |
| Debian/Ubuntu | GitHub CLI | See the [GitHub CLI Debian installation guide](https://github.com/cli/cli/blob/trunk/docs/install_linux.md). |
| Debian/Ubuntu | GitLab CLI | `sudo apt update && sudo apt install glab` |
| Gentoo | GitHub/GitLab CLI | `sudo emerge dev-vcs/gh dev-vcs/glab` |
| Arch | GitHub/GitLab CLI | `sudo pacman -S github-cli glab` |
| macOS | GitHub/GitLab CLI | `brew install gh glab` |
| Windows | GitHub/GitLab CLI | `winget install --id GitHub.cli` / `winget install --id GitLab.glab` |

The development container includes its own toolchain; see its [installed tools](containers/dev-dotfiles-debian/README.md#installed-tools-and-verification) rather than treating these host installation examples as container setup instructions.

## Flatpak applications

Apps used in this environment include AuthPass (`app.authpass.AuthPass`), Bitwarden (`com.bitwarden.desktop`), Beeper (`com.beeper.Beeper`), Dropbox (`com.dropbox.Client`), Chrome (`com.google.Chrome`), RustDesk (`com.rustdesk.RustDesk`), Spotify (`com.spotify.Client`), Steam (`com.valvesoftware.Steam`), FluffyChat (`im.fluffychat.Fluffychat`), nheko (`im.nheko.Nheko`), Element (`im.riot.Riot`), Anytype (`io.anytype.anytype`), Ente Auth (`io.ente.auth`), RSS Guard (`io.github.martinrotter.rssguard`), Picocrypt (`io.github.picocrypt.Picocrypt`), Speech Note (`net.mkiol.SpeechNote`), ImHex (`net.werwolv.ImHex`), Drawy (`org.kde.drawy`), Marknote (`org.kde.marknote`), LibreOffice (`org.libreoffice.LibreOffice`), LocalSend (`org.localsend.localsend_app`), Firefox (`org.mozilla.firefox`), Thunderbird (`org.mozilla.thunderbird`), and Signal (`org.signal.Signal`).

To install them from Flathub:

```sh
flatpak install -y flathub app.authpass.AuthPass com.beeper.Beeper com.bitwarden.desktop com.dropbox.Client com.google.Chrome com.rustdesk.RustDesk com.spotify.Client com.valvesoftware.Steam im.fluffychat.Fluffychat im.nheko.Nheko im.riot.Riot io.anytype.anytype io.ente.auth io.github.martinrotter.rssguard io.github.picocrypt.Picocrypt net.mkiol.SpeechNote net.werwolv.ImHex org.kde.drawy org.kde.marknote org.libreoffice.LibreOffice org.localsend.localsend_app org.mozilla.firefox org.mozilla.thunderbird org.signal.Signal
```

## Credentials and Git

### Application-specific tokens

For scripts requiring secure tokens that should not be globally exported (e.g. `slackpm`), standard behavior is to store the token in an application-specific file with strict `600` or `400` permissions. For example, `slackpm` will fallback to loading its token from `~/.config/slackpm/token` if the `$SLACK_TOKEN` environment variable is not explicitly set.

Do not mount the host's password store or entire credential directory into dev containers. Keep credential files scoped and private.

To safely create this file without leaking your token to your shell history, create an empty file under a strict umask first, then edit it. Verify the permissions after saving, as some text editors may replace the file entirely:

```sh
mkdir -p ~/.config/slackpm
chmod 700 ~/.config/slackpm
(umask 077 && touch ~/.config/slackpm/token)
# Open ~/.config/slackpm/token in your preferred editor and paste your token
ls -l ~/.config/slackpm/token # Verify it is still -rw-------
```

### Encrypt credentials with ejson

Use [ejson](https://github.com/Shopify/ejson) to store encrypted values such as a GitLab OAuth client ID. Generate a keypair with `ejson keygen -w`, retain the private key securely, and create `private_gitlab_oauth.ejson` with your generated public key:

```json
{
  "_public_key": "<public key>",
  "gitlab_oauth_client_id": "<your client ID>"
}
```

Run `ejson encrypt private_gitlab_oauth.ejson`. Store the private key where ejson can read it when applying the dotfiles. Change the JSON field names to fit the secrets you need. Do not commit an unencrypted secret or its private key.

### Git templates and editor

Chezmoi copies `dot_config/git/template` to `~/.config/git/template`; Git uses it to initialize new repositories. Edit the stub `README.md` and `.gitignore` in that *template directory* to customize newly initialized repositories. These are functional templates, not extra documentation guides to consolidate.

`dot_gitconfig.tmpl` selects an available default editor. On Windows it searches the `ProgramFiles`, `ProgramFiles(x86)`, and `SystemRoot` directories and prefers Notepad++, gVim, VS Code, IntelliJ, then Notepad. Other systems use Neovim or Vim when available. To override the default after applying the dotfiles:

```sh
git config --global core.editor <command>
```

### SSH configuration

The default SSH configuration adds keys to the agent and uses platform-appropriate keychain options and configured identities. On macOS, a host entry may use:

```sshconfig
Host *
  UseKeychain yes
  AddKeysToAgent yes
  IdentitiesOnly yes
```

For an exception, add a more specific `Host` block with the options that the target needs, for example:

```sshconfig
Host legacy.example.com
  UseKeychain no
  AddKeysToAgent no
  IdentitiesOnly no
```

## Desktop and shell notes

### Hyprland shortcuts

See the [Hyprland keyboard shortcut reference](HYPRLAND_KEYBOARD_SHORTCUTS.md) when you need the full bindings table. This is a separate on-demand *reference sheet*, not a competing setup guide; the binding configuration remains the source of truth. Coding-agent maintenance instructions for it are in [`AGENTS.md`](AGENTS.md).

### X1 laptop touchpad (Hyprland)

On the `x1linux` ThinkPad, `dot_config/hypr/local_x1linux.lua` is selected by the hostname-based loader in `dot_config/hypr/hyprland.lua.tmpl`. Its per-device `hl.device` override targets only `synaptics-tm3512-010`, not the ELAN TrackPoint, desktop2, or external mice. It temporarily disables tap-to-click and tap-and-drag to help distinguish unwanted tap clicks from a physical-button or lower-level libinput problem. Physical clicks and two-finger scrolling are not disabled.

On `x1linux`, review and apply the update without affecting other machines:

```sh
chezmoi diff ~/.config/hypr/local_x1linux.lua
chezmoi apply ~/.config/hypr/local_x1linux.lua
hyprctl reload
hyprctl configerrors
```

Compare a physical click on the lower touchpad with the TrackPoint buttons above it, and separately try moving the TrackPoint before touching the pad. A movement pause following TrackPoint activity may be libinput's disable-while-trackpointing behaviour; turning off tap recognition is **not** guaranteed to resolve it. If physical clicks still register twice, inspect `sudo libinput list-devices` and `sudo libinput debug-events --device /dev/input/eventN` (use the Synaptics device's actual event path). A normal two-finger scroll should generate finger-scroll events, rather than pinch events. Do not use `--grab` while observing normal desktop behaviour.

If Firefox alone zooms the focused content during two-finger scrolling, set `apz.gtk.touchpad_pinch.enabled` to `false` in `about:config` **in the X1's Firefox profile** as a diagnostic workaround. The dotfiles do not automatically change Firefox profile preferences or disable legitimate pinch zoom on other hosts. Re-enable it if later testing resolves the false pinch events. To roll back the touchpad experiment, remove the device block from the host module, reapply with chezmoi, and reload Hyprland.

### KDE setup

Chezmoi includes a run-once script that sets KDE's superuser command to `sudo` if `kwriteconfig6` is present. If you install KDE after applying these dotfiles, run `chezmoi apply` again to trigger the script.

### Foot terminal

The dotfiles include a [foot](https://codeberg.org/dnkl/foot) Wayland terminal template. Install foot using your package manager, then apply with `chezmoi apply`. On systems using `update-alternatives`, set it as the terminal with:

```sh
sudo update-alternatives --set x-terminal-emulator /usr/bin/foot
```
