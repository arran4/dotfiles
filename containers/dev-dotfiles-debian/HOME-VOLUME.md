# Project-scoped home volume (opt-in prototype)

This is an **alternative image**, not a change to the currently published `dev-dotfiles-debian` image or the existing launcher examples in `README.md`. It demonstrates consolidating the four agent/forge configuration volumes into one per-project home volume **without deciding how `/workspace` is supplied**.

## Layout and upgrade lifecycle

| Location | Purpose |
| --- | --- |
| `dev-agent-${name}-home` mounted at `/home/user` | One optional project-scoped home volume for dotfiles, shell history, and CLI/agent authentication |
| `/workspace` | A **real, independent directory**: bind mount, named volume, imported repository, or ordinary container filesystem; never a symlink into the home volume |
| `~/workspace` | Optional convenience symlink pointing **to `/workspace`**, created in the image seed only if that home path does not already exist |
| `/usr/local/share/dev-dotfiles-debian/home-seed.tar` | Archive of the image's prepared home, outside any home volume |
| `/usr/local/share/dev-dotfiles-debian/home-seed-version` | Image build version plus SHA-256 of that archive |
| `~/.dev-dotfiles-seed-version` | Last successfully applied seed version, inside the home directory |

The image builds all tools and applies chezmoi before archiving the prepared home. On container start, `DEV_HOME_VOLUME_INIT=1` enables a version check. If the home has no applied-version marker, the entrypoint overlays the archive onto it. If the marker matches the image seed version, it leaves home untouched. If the image version or archived home contents change, it overlays the archive once again, overwriting matching dotfiles while preserving paths that exist only in home. The marker is updated atomically **after** successful extraction so an interrupted update is retried. A running container must be recreated with the newer image to trigger the new version; `podman start` on an existing container does not update its image.

On *upgrades*, the entrypoint excludes existing shell histories, GitHub/GitLab CLI configuration, and known Codex/Antigravity authentication/session paths from the overlay. Other matching home configuration files, **including locally edited dotfiles**, are overwritten intentionally. The seed should never contain host credentials; it is produced at image build time. The exclusion list is not a universal guarantee for unknown applications' session paths: review it before adding agent state to the image seed. Runtime-only files absent from the archive are preserved. The user can keep a local config override in a path not included in the seed.

The opt-in flag does **not** detect whether `/home/user` is a named volume, a bind mount, or the image's own writable filesystem. Never mount your host home directory there and then opt into seeding: matching host files would be overwritten.

## Build (from the dotfiles repository root)

```sh
podman build -f containers/dev-dotfiles-debian/Dockerfile.home-volume \
  --build-arg BASE_IMAGE=ghcr.io/arran4/dev-dotfiles-debian:latest \
  --build-arg IMAGE_VERSION=home-volume-trial-1 \
  -t dev-dotfiles-home-volume:trial .
```

For a later image release, use the new release/commit for `IMAGE_VERSION` and rebuild. The seed also carries an archive digest, so a change to the prepared home refreshes the version even when that build argument is unchanged.

## Workspace modes

All modes keep `/workspace` as an ordinary directory. Use a unique `name` per project and the same home volume name after replacing a container.

**A. Bind-mounted project checkout; one project home volume.** Run from the directory to work on:

```sh
name=home-volume-trial
podman run -it --name "dev-agent-${name}" --restart=no \
  --userns=keep-id:uid=1000,gid=1000 \
  --hostname "agent-sandbox-${name}" --env DEV_HOME_VOLUME_INIT=1 \
  --workdir /workspace \
  --mount "type=volume,src=dev-agent-${name}-home,dst=/home/user" \
  --mount "type=bind,src=$(pwd -P),dst=/workspace,rw" \
  dev-dotfiles-home-volume:trial
```

This keeps the host checkout outside the home volume and does not bind-mount host authentication. The home volume persists independently of the container. The host checkout continues to exist if the container is removed.

**B. Existing independent project volume or imported Git repository.** Use the same command as A, but replace the bind mount with:

```sh
  --mount "type=volume,src=dev-agent-${name}-workspace,dst=/workspace" \
```

That is **two named volumes**, not one: one for home and one for an independently persistent workspace. This retains the current disconnected-project architecture while replacing the four separate agent/forge state volumes. An existing `-workspace` volume can be reused as-is, including a repository or bare Git repository already in it; the home initializer does not touch `/workspace`. For an empty workspace, clone a project or import a repository there using your existing workflow. If Podman creates the workspace volume root as unwritable by the non-root user, fix ownership of that mount-point root explicitly rather than recursively chowning an imported repository.

**C. Home volume, no workspace mount.** Omit the bind or workspace-volume mount from A. Work in the container's ordinary `/workspace` directory; `git clone` and `git clone --bare` both work there. Stopping and restarting that **same container** retains the workspace in its writable layer; removing the container loses the workspace even though the home volume survives. Copy it out before removing or recreating the container.

**D. No volumes at all.** Omit both mount flags from A. Keep `--env DEV_HOME_VOLUME_INIT=1`: despite its historical name, it also initializes the image's ordinary writable `/home/user` directory. Home and workspace survive `podman start` of the same container, but **both are lost when the container is removed**. This is useful for a disposable experiment; do not use `--rm` if you expect to resume it.

For any mode, stop and resume the same named container with:

```sh
podman start -ai --detach-keys="" dev-agent-home-volume-trial
```

Docker can run the same OCI image with `docker run` and the same mounts; omit Podman's `--userns=keep-id:uid=1000,gid=1000` if unsupported by your Docker installation. Do not mount additional volumes over `~/.codex`, `~/.gemini`, `~/.config/gh`, or `~/.config/glab-cli` when using the consolidated home.

## Existing project volumes: do not delete or silently migrate

The current persistent sandbox has five named volumes: `-workspace`, `-codex`, `-agy`, `-gh`, and `-glab`. The new `-home` volume **does not** automatically import any of them. Keep the old `-workspace` mounted at `/workspace`, and copy only the other four state volumes into the corresponding directories in the **new** home volume using a one-off migration container while the old container is stopped. Review ownership and permissions after copying and reauthenticate where a source application's keyring cannot be migrated. Do not remove the old container or its state volumes until the new sandbox is verified. Never mount the old subdirectory volumes over the new home volume in the regular sandbox: nested mounts conceal the consolidated state.

## Verification and limitations

Run `sh containers/dev-dotfiles-debian/test-home-volume.sh` for a local first-run/restart/image-upgrade/failure regression check. A full image build and actual rootless Podman/Docker lifecycle test are required before switching the default launcher. The prototype derives from an already-built upstream image, so old image layers retain the baked home: integrating the archive directly into the **primary Dockerfile** would avoid that duplication. The default published image and existing launcher examples remain unchanged until that integration is reviewed.
