# Project-scoped home volume (opt-in prototype)

This is an **alternative image**, not a change to the currently published `dev-dotfiles-debian` image or the existing launcher examples in `README.md`. It demonstrates what a single project volume would look like before changing the default or migrating existing sandboxes.

## Layout and lifecycle

| Location | Purpose |
| --- | --- |
| `dev-agent-${name}-home` mounted at `/home/user` | The **only named volume**: workspace, dotfiles, shell history, GitHub/GitLab auth, Codex and Antigravity state |
| `/workspace` | Image-provided symlink to `/home/user/workspace`, preserving existing agent workflows |
| `/usr/local/share/dev-dotfiles-debian/home-seed.tar` | Image-owned snapshot of the fully prepared home; outside the volume mount |
| `$HOME/.dev-dotfiles-home-initialized` | First-run completion marker inside the volume |

The image first installs tools and applies chezmoi exactly as the existing image does. The variant packages that prepared home as a tar archive outside the home directory and removes the runtime home contents. `DEV_HOME_VOLUME_INIT=1` opts into extracting the seed archive on first start. GNU tar overlays matching files, leaves unrelated files intact, and writes the marker **only after successful extraction**. A restarted sandbox does not run chezmoi or overwrite existing configuration, history, authentication, or checkouts. A failed first extraction can be retried safely. Do not remove the marker to apply future image updates: doing so intentionally reapplies the full original seed and may overwrite user edits.

The one-time seed is distinct from runtime authentication: the image contains only build-time configuration, never your host tokens or host `$HOME`. A new project gets its own isolated credentials; a second project receives a different named volume.

## Build and run (from the dotfiles repository root)

Build the current main image first if you want to base the experiment on your own local build; otherwise the variant defaults to `ghcr.io/arran4/dev-dotfiles-debian:latest`:

```sh
podman build -f containers/dev-dotfiles-debian/Dockerfile.home-volume \
  --build-arg BASE_IMAGE=ghcr.io/arran4/dev-dotfiles-debian:latest \
  -t dev-dotfiles-home-volume:trial .
```

Create a **new**, host-filesystem-disconnected project sandbox (choose a distinct name to avoid accidentally starting the old container):

```sh
name=home-volume-trial
podman run -it --name "dev-agent-${name}" --restart=no \
  --userns=keep-id:uid=1000,gid=1000 \
  --hostname "agent-sandbox-${name}" \
  --env DEV_HOME_VOLUME_INIT=1 --workdir /workspace \
  --mount "type=volume,src=dev-agent-${name}-home,dst=/home/user" \
  dev-dotfiles-home-volume:trial
```

The image creates `/workspace` as a symlink into `/home/user/workspace`; do **not** mount another volume at `/workspace` or any nested agent configuration directory. To resume the same stopped container, run:

```sh
podman start -ai --detach-keys="" dev-agent-home-volume-trial
```

If you accidentally remove the container, run the `podman run` command again with the **same** volume name and a new container name; only the named volume is necessary to recover the persistent project state. Do not use `--rm` on the volume or remove the named volume unless you intend to erase the project. To destroy this disposable example after copying anything important out:

```sh
podman rm -f dev-agent-home-volume-trial
podman volume rm dev-agent-home-volume-trial-home
```

Docker can run the same OCI image with `docker run` and the same single `--mount`; omit Podman's `--userns=keep-id:uid=1000,gid=1000` if your Docker installation does not support it. For a bind-mounted host checkout, keep the project home volume but mount the checkout at `/home/user/workspace` (never the entire host home). This is a host-filesystem-connected mode rather than the isolated mode shown above.

## Existing project volumes: do not delete or silently migrate

The current instructions have five named volumes per project: `-workspace`, `-codex`, `-agy`, `-gh`, and `-glab`. The new `-home` volume does **not** import any of them. Stop the old container, make a backup, and deliberately copy the old workspace into `/home/user/workspace`, Codex into `/home/user/.codex`, Antigravity into `/home/user/.gemini`, GitHub CLI into `/home/user/.config/gh`, and GitLab CLI into `/home/user/.config/glab-cli` using a separately run migration container with both sets of volumes mounted. Review ownership and permissions after copying and reauthenticate where the source application's keyring cannot be migrated. **Do not remove the old container or its five volumes until the new sandbox has been tested with the existing repositories and credentials.** Never mount both the old subdirectory volumes and the new home volume into the normal sandbox: nested mounts obscure the home-volume contents.

## Verification and limitations

Run `sh containers/dev-dotfiles-debian/test-home-volume.sh` for a local first-run/restart/partial-initialization regression check. A full image build and actual rootless Podman/Docker lifecycle test are required before switching the default launcher.

This variant is intentionally a prototype: it derives from the already-built upstream image, so the image's earlier layers still contain the original populated home directory. Packaging the archive directly at the end of the **primary Dockerfile**, and updating its smoke tests and published launcher examples, would avoid that redundant image layer when adopting this as the default. Rebuilding the image does not update an already-initialized volume: explicit migration or a separate opt-in reapply mechanism is required to refresh old project dotfiles.
