# arran4 dotfiles

I have maintained a consistent dot file since I think 2004ish perhaps a bit earlier. This repo represents a complete
rewrite. (I have another repo for my older dot configs which earliest commit was 2007ish.. But I had been using it via
diff+ssh, rcs, svn, and finally git. But I didn't port RCS into SVN so I had lost earlier history.) --- Anyway. Enjoy.

I have a lot of things here that was specific to a particular place and time which are probably no longer relevant,
porting them to chezmoi was I guess for my own interest sake.

# Usage

I recommend you copy and paste the good stuff out into your own chezmoi config rather than just mine there is a lot of
config here which is specific to me or specific to a particular situation I had been in in the past.

Using chezmoi https://www.chezmoi.io/

If chezmoi prints `warning: config file template has changed`, rerun `chezmoi init --apply arran4` to regenerate the configuration
from `.chezmoi.toml.tmpl`.

# Notes

I don't think it's a good idea just to apply my dot files on to your system as there are a lot of configuration options
and scripts I have put in intentionally, these could go unnoticed or taken for granted (which will make switching to
other systems harder.) Saying that please pick out what you like / want. I am also happy to take suggestions in the form
of PR or issues.


# Benefits

Using these dotfiles provides a quick way to bootstrap a consistent development
environment across multiple platforms. Everything is driven by
[chezmoi](https://www.chezmoi.io/) so you can apply or customize the configuration
with a single command.

Highlights include:

- Zsh and Bash setups with a shared prompt and a library of useful aliases (see `.chezmoitemplates`).
- `.gitconfig.tmpl` that wires in the best available editor, color output and credential helpers.
- Minimal tmux config with mouse mode and zsh as the default shell.
- Personal Caelestia/Quickshell configuration (Caelestia Shell itself is expected to be installed as a system package via Portage).
- Example `.vimrc` and support files for Vim or Neovim.
- OS-aware templates (`.chezmoi.toml.tmpl`) that select paths and tools based on your platform.
- Scripts for one-time tasks located in `.chezmoiscripts/` that run automatically on the first apply.
- Conditional `.chezmoiignore` rules skip local executables like
  `gh-release.sh` when dependencies such as the GitHub CLI (`gh`) are absent.

Feel free to copy individual pieces or adapt the whole setup to suit your needs.

## Dev Tools

### Cross-Platform

| Tool | Installation Command |
|---|---|
| golangci-lint | `go install github.com/golangci/golangci-lint/v2/cmd/golangci-lint@latest` |
| gcm | See [Git Credential Manager](https://github.com/git-ecosystem/git-credential-manager) |
| CLIProxyAPI | `go install github.com/router-for-me/CLIProxyAPI/v6/cmd/server@latest && mv $HOME/go/bin/server $HOME/.local/bin/CLIProxyAPI` |

### Debian/Ubuntu

| Tool | Installation Command |
|---|---|
| gh | `(type -p wget >/dev/null || (sudo apt update && sudo apt install wget -y)) && sudo mkdir -p -m 755 /etc/apt/keyrings && out=$(mktemp) && wget -nv -O$out https://cli.github.com/packages/githubcli-archive-keyring.gpg && cat $out | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null && sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg && sudo mkdir -p -m 755 /etc/apt/sources.list.d && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null && sudo apt update && sudo apt install gh -y` |
| glab | `sudo apt update && sudo apt install glab` |

### Gentoo

| Tool | Installation Command |
|---|---|
| gh | `sudo emerge dev-vcs/gh` |
| glab | `sudo emerge dev-vcs/glab` |

### Arch

| Tool | Installation Command |
|---|---|
| gh | `sudo pacman -S github-cli` |
| glab | `sudo pacman -S glab` |

### Mac OS X

| Tool | Installation Command |
|---|---|
| gh | `brew install gh` |
| glab | `brew install glab` |

### Windows

| Tool | Installation Command |
|---|---|
| gh | `winget install --id GitHub.cli` |
| glab | `winget install --id GitLab.glab` |

## Containerised development environment

The development image under [`containers/dev-dotfiles-debian`](containers/dev-dotfiles-debian/README.md) is published as
`ghcr.io/arran4/dev-dotfiles-debian:latest`. It can be run with either Podman or Docker. For full-access AI agents,
treat the outer container as the security boundary and mount only the repository the agent should be able to modify.
Rootless Podman is preferred because its `keep-id` user namespace mode maps the invoking host user directly to the
container's `user` account.

### Podman (recommended)

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

### Docker

The same OCI image can be used with Docker. Prefer Docker's rootless mode when available. For a conventional Docker
setup where the host account is UID/GID `1000`, matching the image defaults, the equivalent command is:

```sh
docker run --rm -it \
  --hostname agent-sandbox \
  --workdir /workspace \
  --mount type=bind,src="$PWD",dst=/workspace,rw \
  --mount type=volume,src=dev-agent-codex,dst=/home/user/.codex \
  --mount type=volume,src=dev-agent-agy,dst=/home/user/.gemini \
  ghcr.io/arran4/dev-dotfiles-debian:latest
```

Docker rootless mode maps files owned by the host user to container UID `0`, rather than providing Podman's
`--userns=keep-id` behaviour. If that makes the bind-mounted repository unwritable, run the rootless Docker container
with `--user 0:0 --env HOME=/home/user`. Do not use that workaround with a rootful Docker daemon, because it would run
the agent as real container root and can leave root-owned files in the mounted repository.

Once inside either container, the agents can be run with their own inner restrictions disabled:

```sh
codex --dangerously-bypass-approvals-and-sandbox
```

```sh
agy --dangerously-skip-permissions
```

For container commands that differ only by engine name, Podman and Docker should be treated as alternatives. Do not
blindly copy engine-specific flags between them: in particular, `--userns=keep-id` is a Podman feature. The detailed
container README contains the security boundary and credential-handling guidance.

## Flatpak Apps

I use the following flatpak applications in this environment:
- AuthPass (`app.authpass.AuthPass`)
- Bitwarden (`com.bitwarden.desktop`)
- Beeper (`com.beeper.Beeper`)
- Dropbox (`com.dropbox.Client`)
- Google Chrome (`com.google.Chrome`)
- RustDesk (`com.rustdesk.RustDesk`)
- Spotify (`com.spotify.Client`)
- Steam (`com.valvesoftware.Steam`)
- FluffyChat (`im.fluffychat.Fluffychat`)
- nheko (`im.nheko.Nheko`)
- Element (`im.riot.Riot`)
- Anytype (`io.anytype.anytype`)
- Ente Auth (`io.ente.auth`)
- RSS Guard (`io.github.martinrotter.rssguard`)
- Picocrypt (`io.github.picocrypt.Picocrypt`)
- Speech Note (`net.mkiol.SpeechNote`)
- ImHex (`net.werwolv.ImHex`)
- Drawy (`org.kde.drawy`)
- Marknote (`org.kde.marknote`)
- LibreOffice (`org.libreoffice.LibreOffice`)
- LocalSend (`org.localsend.localsend_app`)
- Firefox (`org.mozilla.firefox`)
- Thunderbird (`org.mozilla.thunderbird`)
- Signal Desktop (`org.signal.Signal`)

You can install them automatically with this one-liner:
```sh
flatpak install -y flathub app.authpass.AuthPass com.beeper.Beeper com.bitwarden.desktop com.dropbox.Client com.google.Chrome com.rustdesk.RustDesk com.spotify.Client com.valvesoftware.Steam im.fluffychat.Fluffychat im.nheko.Nheko im.riot.Riot io.anytype.anytype io.ente.auth io.github.martinrotter.rssguard io.github.picocrypt.Picocrypt net.mkiol.SpeechNote net.werwolv.ImHex org.kde.drawy org.kde.marknote org.libreoffice.LibreOffice org.localsend.localsend_app org.mozilla.firefox org.mozilla.thunderbird org.signal.Signal
```

### Try it out

1. Clone the repository and run `./install`.
2. Version checks run during setup using a PATH built from the `paths` defined in `.chezmoi.toml.tmpl` and warn only when a tool is older than the listed minimum version or the comparison fails.
3. Open a new terminal and check the prompt, aliases and git settings.
4. Start `tmux` to see the multiplexer configuration.
5. Inspect `.chezmoitemplates` to learn how the templates are structured.

## Encrypting credentials with ejson

Use ejson to store secrets such as a GitLab OAuth client ID. Create an encrypted
file named `private_gitlab_oauth.ejson`:

1. Install [ejson](https://github.com/Shopify/ejson).
2. Generate a keypair and save the secret key:

   ```sh
   ejson keygen -w
   ```

   Note the printed public key and keep the private key in the output path.
3. Create `private_gitlab_oauth.ejson` containing your public key and OAuth client ID:

   ```json
   {
     "_public_key": "<public key>",
     "gitlab_oauth_client_id": "<your client ID>"
   }
   ```

4. Encrypt the file:

   ```sh
   ejson encrypt private_gitlab_oauth.ejson
   ```

Store the private key where `ejson` can read it when applying your dotfiles.
Feel free to change the JSON keys to suit whichever credentials you need to
encrypt.

## Git template files

Git initialises new repositories using the contents of
`~/.config/git/template`. `chezmoi` copies everything under
`dot_config/git/template` into this directory. Update the stub `README.md` and
`.gitignore` files there to provide your own defaults for new repositories,
then run `chezmoi apply` to install them.

## KDE setup

Chezmoi includes a run-once script that sets KDE's super user command to `sudo` when `kwriteconfig6` is present. If you install KDE after applying these dotfiles, run `chezmoi apply` again to trigger the script.

## Git editor selection

`dot_gitconfig.tmpl` chooses a default editor based on what is installed. On
Windows it searches the directories pointed to by the `ProgramFiles`,
`ProgramFiles(x86)` and `SystemRoot` environment variables. GUI tools are
preferred: `notepad++`, `gvim`, Visual Studio Code (`code`), IntelliJ
(`idea64`) and finally plain `notepad`. Other systems use `neovim` or `vim`
when available.
If you want a different editor, override the setting after applying the
dotfiles:

```sh
git config --global core.editor <command>

## SSH configuration

The default SSH configuration adds keys to your agent, stores passphrases in the
macOS keychain and limits authentication to the specified identities:

```sshconfig
Host *
  UseKeychain yes
  AddKeysToAgent yes
  IdentitiesOnly yes
```

To disable or override these options, create another `Host` block with your
preferred values. For example:

```sshconfig
Host legacy.example.com
  UseKeychain no
  AddKeysToAgent no
  IdentitiesOnly no
```

## Foot terminal emulator

These dotfiles include a template for [foot](https://codeberg.org/dnkl/foot), a
fast Wayland terminal. Install foot from your package manager and apply the
configuration:

```sh
chezmoi apply
```

To make foot the default terminal on systems that support `update-alternatives`,
run:

```sh
sudo update-alternatives --set x-terminal-emulator /usr/bin/foot
```
