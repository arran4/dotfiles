# Versioned project home (opt-in prototype)

The current published `ghcr.io/arran4/dev-dotfiles-debian:latest` image still uses the original separate agent/forge volumes. PR #464 adds **an alternative, locally built image** using `Dockerfile.home-volume`; do not run its commands against the published `:latest` tag. The existing container documentation distinguishes these two images until the primary image and launchers are migrated.

## Build the alternative image

From the dotfiles repository root (with either engine):

```sh
podman build -f containers/dev-dotfiles-debian/Dockerfile.home-volume \
  --build-arg BASE_IMAGE=ghcr.io/arran4/dev-dotfiles-debian:latest \
  --build-arg IMAGE_VERSION=home-volume-trial-1 \
  -t dev-dotfiles-home-volume:trial .
```

Replace `podman build` with `docker build` when using Docker. `BASE_IMAGE` may instead refer to a locally built primary image. For another release, rebuild and change `IMAGE_VERSION` (prefer a real release or commit identifier). The archive digest is also included in the image's seed version.

## Paths and lifecycle

| Path | Purpose |
| --- | --- |
| `/home/user` | Optional per-project named volume `dev-agent-${name}-home`; holds dotfiles, history, forge and agent state |
| `/workspace` | An ordinary **independent directory**: host bind mount, named volume, imported/bare Git repository, or the container's writable filesystem |
| `~/workspace` | Optional seed-provided convenience link **to** `/workspace`; never makes `/workspace` a link into home |
| `/usr/local/share/dev-dotfiles-debian/home-seed.tar` | Prepared image home, outside `/home/user` |
| `/usr/local/share/dev-dotfiles-debian/home-seed-version` | Image-build identifier and archive digest |
| `~/.dev-dotfiles-seed-version` | Version last successfully applied to this home |

`DEV_HOME_VOLUME_INIT=1` enables seeding for the experimental image. On a new home, matching seed files are copied over existing files, while paths absent from the seed remain. On subsequent starts with the **same** seed version, no overlay runs. On a changed image seed version, matching configuration is overlaid again and locally edited seeded dotfiles may be overwritten. On upgrades, the initializer excludes known shell histories, GitHub/GitLab CLI configurations and Codex/Antigravity authentication/session paths; unknown applications' credentials may need separate protection. Only successful extraction advances the stored version. The flag does not verify that home is a volume: never bind mount your host home to `/home/user` with this flag.

**An image upgrade requires replacing the container**, not merely running `podman start` or `docker start`: existing container objects retain their old image. Back up important home changes, stop the container, remove only that container object, rebuild the alternative image with the new seed, and run a new container with the same project-home volume name. Retain or restore the workspace separately as appropriate for the selected mode. Do not remove named volumes while replacing the container.

## Launch with Podman

Use a unique project name; do not reuse an existing legacy container name without planning migration. These examples use `name=home-volume-trial`. Rootless Podman uses `--userns=keep-id:uid=1000,gid=1000`; the image defaults to user/UID/GID `user`/`1000`/`1000`.

**Bind-mounted checkout (one named volume, for home):**

```sh
name=home-volume-trial
workspace=$(pwd -P)
podman run -it --name "dev-agent-${name}" --restart=no \
  --userns=keep-id:uid=1000,gid=1000 \
  --hostname "agent-sandbox-${name}" --env DEV_HOME_VOLUME_INIT=1 \
  --workdir /workspace \
  --mount "type=volume,src=dev-agent-${name}-home,dst=/home/user" \
  --mount "type=bind,src=${workspace},dst=/workspace,rw" \
  dev-dotfiles-home-volume:trial
```

**Disconnected, independently persistent project (two volumes):** use the same Podman command, but replace its `/workspace` bind mount with:

```sh
  --mount "type=volume,src=dev-agent-${name}-workspace,dst=/workspace" \
```

An existing `-workspace` volume can be reused, including an imported or bare Git repository. The home initializer never seeds or modifies `/workspace`. For a new empty named workspace, the non-root user may need ownership of the mount-point root adjusted explicitly; do not recursively change imported checkout ownership.

**Import or clone into the container's own workspace:** omit the `/workspace` mount from the bind-mounted example. `/workspace` stays a real directory; clone or import repositories there. Stopping and restarting the **same container** retains them; removing or recreating that container discards its writable workspace. Copy it out or use a workspace volume before an image upgrade.

**No volumes:** omit both `--mount` flags, but retain `DEV_HOME_VOLUME_INIT=1`. Home and workspace are then held only by that container object's writable layer and are lost on removal. This is disposable, not suitable for retaining work or credentials across image replacements.

To resume a stopped named Podman container without replacing its image:

```sh
podman start -ai --detach-keys='' "dev-agent-${name}"
```

Do not use `--rm` when relying on a container's writable layer. Deliberate detachment can leave the shell running; exit the login shell to stop it.

## Launch with Docker

Build the experimental image using `docker build` above. The equivalent **bind-mounted project** launch (normal Docker with a matching UID/GID `1000`) is:

```sh
name=home-volume-trial
workspace=$(pwd -P)
docker run -it --name "dev-agent-${name}" --restart=no \
  --hostname "agent-sandbox-${name}" --env DEV_HOME_VOLUME_INIT=1 \
  --workdir /workspace \
  --mount "type=volume,src=dev-agent-${name}-home,dst=/home/user" \
  --mount "type=bind,src=${workspace},dst=/workspace,rw" \
  dev-dotfiles-home-volume:trial
```

For a disconnected workspace, replace Docker's bind mount with `--mount "type=volume,src=dev-agent-${name}-workspace,dst=/workspace"`. Omit just the workspace mount for an imported/ephemeral project, or both mounts for a fully disposable container, with the same persistence caveats as Podman. Resume with `docker start -ai "dev-agent-${name}"`. Docker does **not** support Podman's `--userns=keep-id`; verify bind-mount permissions under rootless Docker. On native Linux Docker using host Ollama, add `--add-host host.docker.internal:host-gateway` to the `docker run` invocation.

For both engines, this image consolidates the agent/forge configuration into home: do **not** also mount separate `~/.codex`, `~/.gemini`, `~/.config/gh` or `~/.config/glab-cli` volumes over it. Docker-in-Docker is an exceptional mode requiring its own independent `/var/lib/docker` volume and additional privileges; see [DIND.md](DIND.md).

## Migration and cleanup

The original persistent sandbox uses `-workspace`, `-codex`, `-agy`, `-gh` and `-glab` volumes. The experimental `-home` volume **does not import them**. Stop the old container, back up its volumes, and copy each of the four agent/forge volumes into the corresponding directory in the new home using a separate migration container. Retain or mount the original `-workspace` volume at `/workspace` if that project should survive container removal. Verify ownership, repositories and authentication before deleting any old container or volume. In particular, do not mount old agent/forge volumes as nested mounts inside the new home: they conceal its contents. Keyring-backed logins may require reauthentication.

For an intentional cleanup, first identify whether the workspace is bind-mounted, a named volume or only a container writable layer. Remove the named container and **only the specific volumes you intend to discard**; do not reuse legacy five-volume cleanup commands for the experimental home.

## Verification and limitations

From the repository root, run `sh containers/dev-dotfiles-debian/test-home-volume.sh`. Real Podman and Docker tests (first start, same-version restart, new image, container recreation, ownership and volume migration) are still required before making the alternative image the default. This prototype derives from an already-built image, so earlier image layers still contain the baked home; directly integrating the seed into the primary Dockerfile is a separate follow-up.
