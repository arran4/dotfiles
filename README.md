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

# Tools:

| Tool                                                        | Symbols                    | What                                                                                                                                 |
|-------------------------------------------------------------|----------------------------|--------------------------------------------------------------------------------------------------------------------------------------|
| [Chezmoi](https://www.chezmoi.io/)                          | ✅🍎🤖🐧🪟⌨📖               | Dot files syncing tool                                                                                                               |
| zsh                                                         | 📖✅🍎🤖🐧🪟⌨               | Default shell                                                                                                                        |
| zellij                                                      | 📖✅🍎🤖🐧🪟⌨               | Current default multiplexer                                                                                                          |
| tmux                                                        | 📖✅🍎🤖🐧🪟⌨               | Fall back terminal multiplexer                                                                                                       |
| vimdiff                                                     | 📖✅🍎🤖🐧🪟⌨               | Default tui diff compare                                                                                                             |
| vim                                                         | 📖✅🍎🤖🐧🪟⌨               | Current terminal text editor                                                                                                         |
| Go                                                          | 📖✅🍎🤖🐧🪟                | Current favourite system language                                                                                                    |
| Jetbrains products                                          | ✅🍎🤖🐧🪟🖱️⚠              | Favourite IDE                                                                                                                        |
| OpenAI ChatGPT                                              | 🖱️️⚠✅                     | Got to use some sort of LLM these days                                                                                               |
| [Suno AI](https://app.suno.ai/)                             | 🖱️️⚠                      | Great little music generator                                                                                                         |
| [gobookmarks](https://github.com/arran4/gobookmarks)        | 🌐✅📖                      | My "homepage" bookmark system which I had used on and off since the late 90s in various capacities                                   |
| [duf](https://github.com/muesli/duf)                        | 📖✅🍎🐧🪟⌨                 | Easier to read than `df`                                                                                                             |
| [Linkwarden](https://github.com/linkwarden/linkwarden)      | 📖✅🌐🖱️️                      | Link management, reference management and archiving self hosted service                                                              |
| [Bitwarden](https://bitwarden.com/)                         | 📖🍎🤖🐧🪟🌐🖱️️              | Password manager - Growing stale                                                                                                     |
| [AnyType](https://anytype.io/)                              | 📖✅🍎🤖🐧🪟🖱️️               | Note taking app                                                                                                                      |
| [Flutter](https://flutter.dev/)                             | 📖✅🍎🤖🐧🪟🌐⚠             | Cross platform development toolkit                                                                                                   |
| [Which Browser](http://arran4.sdf.org/which_browser/)       | ✅🍎🐧🪟⚠🖱️️                  | Link intention management app                                                                                                        |
| [Gentoo Linux](https://www.gentoo.org/)                     | ✅🐧📖                      | Linux distribution                                                                                                                   |
| [Dendrite](https://github.com/matrix-org/dendrite)          | 📖✅🍎🤖🐧🪟                | Matrix server - self hosted                                                                                                          |
| [Kavita Reader](https://www.kavitareader.com/)              | 📖✅🌐                      | Self hosted comic, ebook, etc reader (webbased)                                                                                      |
| [Gitlab](https://about.gitlab.com/)                         | 📖✅🌐                      | Self hosted Git service                                                                                                              |
| [Omnivore](https://omnivore.app)                            | ⚠🌐                        | Read it later service                                                                                                                |
| [Nheko](https://github.com/Nheko-Reborn/nheko)              | 📖🍎🐧🪟🖱️️                  | Matrix client for desktops                                                                                                           |
| [Fluffy Chat](https://fluffychat.im/)                       | 📖🍎🤖🐧🪟🖱️️                | Matrix client for mobile and desktops                                                                                                |
| [Git](https://git-scm.com/)                                 | 📖✅🌐                      | Version control system                                                                                                               |
| [Synology Audio Station](https://www.synology.com/en-us)    | ⚠🌐🍎🤖                    | Music player and streaming product - self hosted                                                                                     |
| [Synology Drive](https://www.synology.com/en-us)            | 🍎🤖🐧🪟🌐⚠                | Online document editing system                                                                                                       |
| [Synology NAS](https://www.synology.com/en-us)              | ⚠🌐                        | Network attached storage                                                                                                             |
| [Synology MailPlus](https://www.synology.com/en-us)         | 🍎🤖🐧🪟🌐⚠                | Mail server                                                                                                                          |
| [Synology Container Manager](https://www.synology.com/en-us) | ⚠🌐                        | Docker and docker compose manager                                                                                                    |
| [Libra Office](https://www.libreoffice.org/)                | 📖✅🍎🐧🪟                  | Local office suite                                                                                                                   |
| [Mastodon](https://mstdn.party/)                            | 📖🌐                       | Federated Microblogging platform - self hostable                                                                                     |
| [Lemmy](https://aussie.zone/)                               | 📖🌐                       | Federated Linksharing forum                                                                                                          |
| [Docker](https://www.docker.com/)                           | 📖✅🍎🐧🪟                  | Containerization service                                                                                                             |
| [7zip](https://www.7-zip.org/)                              | 📖✅🐧🪟                    | Archive extractor, viewier and creator                                                                                               |
| [Plex](https://www.plex.tv/)                                | ✅🍎🤖🐧🪟🌐⚠🖱️️              | Self hosted media streaming service                                                                                                  |
| [Plex Amp](https://www.plex.tv/en-au/plexamp/)              | ✅🍎🤖🪟🌐⚠🖱️️                | Self hosted music and podcast streaming service                                                                                      |
| [Firefox](https://www.mozilla.org/en-US/firefox/)           | 📖🍎🤖🐧🪟🖱️️               | You gotta have a web-browser all of them plainly suck, the reason other than games and LLMs people upgrade their computers these days |
| [Kleopatra](https://www.openpgp.org/software/kleopatra/)    | 📖🐧🪟🖱️️               | GPG certificate manager                                                                                                              |
| [Strawberry](https://www.strawberrymusicplayer.org/)        | ✅🍎🤖🐧🪟🌐🖱️️              | Desktop Music Player                                                                                                                 |
| [Audacious](https://audacious-media-player.org/)            | 🍎🤖🐧🪟🌐🖱️️               | Desktop Music Player - With winamp skin support                                                                                      |
| [Uptimed](https://github.com/rpodgorny/uptimed)             | 📖✅🍎🤖🐧🪟⌨               | A (local) service that keeps a record of all your uptimes |

## Legend

| Symbol | Meaning                                            |
|--------|----------------------------------------------------|
| ✅      | My top choices                                     |
| 📖     | Opensource                                         |
| ⌨️     | CLI/TUI only                                       |
| 🖱️️   | Desktop UI app only                                |
| 🧐     | I have personally used and inspected this software |
| ⚠️     | Software is proprietary                            |
| 🕒     | Software is outdated/abandoned                     |
| 🍎     | Available for Apple products                       |
| 🤖     | Available for Android products                     |
| 🐧     | Available for Linux                                |
| 🪟     | Available for Windows                              |
| 🌐     | Available online                                   |

# Interesting tools:

* https://github.com/tep/terminal-decor

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
```
