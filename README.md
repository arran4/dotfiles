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
- Example `.vimrc` and support files for Vim or Neovim.
- OS-aware templates (`.chezmoi.toml.tmpl`) that select paths and tools based on your platform.
- Scripts for one-time tasks such as updating the font cache.
- Conditional `.chezmoiignore` rules skip local executables like
  `gh-release.sh` when dependencies such as the GitHub CLI (`gh`) are absent.

Feel free to copy individual pieces or adapt the whole setup to suit your needs.

### Try it out

1. Clone the repository and run `./install`.
2. Open a new terminal and check the prompt, aliases and git settings.
3. Start `tmux` to see the multiplexer configuration.
4. Inspect `.chezmoitemplates` to learn how the templates are structured.

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

