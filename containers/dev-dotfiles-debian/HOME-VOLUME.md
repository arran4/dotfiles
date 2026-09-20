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

## Linux launch scripts

The launchers are chezmoi-managed host commands: [`run-dev-podman.sh`](../../dot_local/bin/executable_run-dev-podman.sh) and [`run-dev-docker.sh`](../../dot_local/bin/executable_run-dev-docker.sh). Their **source files are in `dot_local/bin/`**, with the `executable_` prefix so chezmoi installs them to `~/.local/bin/` under their normal command names. Apply this dotfiles branch with chezmoi and ensure `~/.local/bin` is on your `PATH`. Run either command from the host **project directory**, not the dotfiles directory: the default bind-mounted `/workspace` is the caller's current directory and the sandbox name derives from its basename.

```sh
cd ~/Documents/Projects/my-project
run-dev-podman.sh
# Or, if the trial image was built with Docker:
run-dev-docker.sh
```

If chezmoi has not installed the commands yet, run their source files from the project directory using an absolute path to the dotfiles checkout, e.g. `~/Documents/Projects/dotfiles/dot_local/bin/executable_run-dev-podman.sh`. They remain Linux-only, and the multiline `run` commands below remain available for manual customization.

Use `SANDBOX_NAME=my-project` to give a sandbox a stable, distinct name regardless of the current directory. The launchers default to `dev-dotfiles-home-volume:trial` (locally built with the matching engine), a named project-home volume, a host checkout bind-mounted at `/workspace`, a persistent named container, and **no** nested Docker daemon. Override the image with `DEV_IMAGE=<locally-built-home-volume-image>`; they intentionally reject the published legacy `ghcr.io/arran4/dev-dotfiles-debian:<tag>` image, which does not implement home seeding.

Environment options for **both** launchers:

| Setting | Default | Meaning |
| --- | --- | --- |
| `SANDBOX_NAME` | Current directory basename | Project-specific container and named-volume prefix; normalized to a lowercase Docker-safe name |
| `DEV_WORKSPACE_MODE` | `bind` | `bind` mounts the current host directory, `volume` mounts the separate persistent `-workspace` volume, `container` uses the container's writable `/workspace` |
| `DEV_HOME_MODE` | `volume` | `volume` mounts the persistent `-home` volume; `container` stores home only in the container's writable layer |
| `DEV_IMAGE` | `dev-dotfiles-home-volume:trial` | Alternative image already built in the selected container engine |
| `DEV_DIND` | `0` | `1` enables privileged nested Docker; never passes through the host Docker socket |
| `DEV_DIND_PERSIST` | `0` | With `DEV_DIND=1`, `1` adds an **optional** `/var/lib/docker` volume; otherwise its state is volatile across outer-container removal |
| `DEV_DOCKER_HOST_GATEWAY` | `0` | Docker script only: `1` adds the native Linux `host.docker.internal:host-gateway` mapping for host Ollama |

For example, a disconnected project with its own persistent workspace and home:

```sh
SANDBOX_NAME=my-project DEV_WORKSPACE_MODE=volume run-dev-podman.sh
```

To work entirely inside a named container with no mounts, use `DEV_WORKSPACE_MODE=container DEV_HOME_MODE=container`. The scripts do **not** pass `--rm`, because that would destroy workspace or home data stored only in the container's writable layer. If the named container is stopped, the same script resumes it rather than creating another one; if it is already running, it prints an `exec` command for another shell. **Resuming keeps the old image and ignores any newly selected mount/mode options.** To use a rebuilt image or change modes, explicitly back up any writable-layer data, remove only the old container object, and rerun the script with the same named volumes. Neither launcher deletes volumes or migrates legacy state.

The scripts assume the trial image's default user is UID/GID `1000:1000`. The Podman script uses rootless `--userns=keep-id:uid=1000,gid=1000`; the Docker script omits that Podman-specific option and requires independently compatible bind-mount permissions. `DEV_DIND=1` uses outer `--privileged`, so review the security considerations in [DIND.md](DIND.md) before enabling it. The multiline examples below remain available for manual customization and for comparing the exact engine arguments.

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

## Workspace modes

All modes keep `/workspace` as an ordinary directory. Use a unique Docker/Podman-safe `name` per project and the same home volume name after replacing a container. The commands below use `name=home-volume-trial`; adapt the workspace and container name as needed. A host checkout, an independently persistent volume, a repository imported into the container filesystem, and a fully disposable container are all supported. The home seeding process does not determine or modify the workspace layout.

### Launch with Podman

**Bind-mounted checkout (one named volume, for home):** run from the directory to work on:

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

### Launch with Docker

Build the experimental image using `docker build` above. The equivalent **bind-mounted project** launch (normal Docker with a matching UID/GID `1000`) is:

```sh
name=home-volume-trial
docker run -it --name "dev-agent-${name}" --restart=no \
  --hostname "agent-sandbox-${name}" --env DEV_HOME_VOLUME_INIT=1 \
  --workdir /workspace \
  --mount "type=volume,src=dev-agent-${name}-home,dst=/home/user" \
  --mount "type=bind,src=$(pwd -P),dst=/workspace,rw" \
  dev-dotfiles-home-volume:trial
```

For a disconnected workspace, replace Docker's bind mount with `--mount "type=volume,src=dev-agent-${name}-workspace,dst=/workspace"`. Omit just the workspace mount for an imported/ephemeral project, or both mounts for a fully disposable container, with the same persistence caveats as Podman. Resume with `docker start -ai "dev-agent-${name}"`. Docker does **not** support Podman's `--userns=keep-id`; verify bind-mount permissions under rootless Docker. On native Linux Docker using host Ollama, add `--add-host host.docker.internal:host-gateway` to the `docker run` invocation.

For both engines, this image consolidates the agent/forge configuration into home: do **not** also mount separate `~/.codex`, `~/.gemini`, `~/.config/gh` or `~/.config/glab-cli` volumes over it. Docker-in-Docker is an exceptional mode requiring additional privileges, but **not a Docker-data volume**. By default `/var/lib/docker` stays in the outer container's writable layer and is discarded when that container is removed; the nested images, cache and inner containers are not carried into a replacement container. To preserve nested Docker state across outer-container recreation, deliberately add a separate optional volume at `/var/lib/docker` as described in [DIND.md](DIND.md#nested-docker-data-lifetime). The home volume does not contain Docker daemon data.

## Migration and cleanup

The original persistent sandbox uses `-workspace`, `-codex`, `-agy`, `-gh` and `-glab` volumes. The experimental `-home` volume **does not import them**. Stop the old container, back up its volumes, and copy each of the four agent/forge volumes into the corresponding directory in the new home using a separate migration container. Retain or mount the original `-workspace` volume at `/workspace` if that project should survive container removal. Verify ownership, repositories and authentication before deleting any old container or volume. In particular, do not mount old agent/forge volumes as nested mounts inside the new home: they conceal its contents. Keyring-backed logins may require reauthentication.

For intentional cleanup, first identify whether the workspace is bind-mounted, a named volume or only a container writable layer. Remove the named container and **only the specific volumes you intend to discard**; do not reuse legacy five-volume cleanup commands for the experimental home.

## Verification and limitations

From the repository root, run `sh containers/dev-dotfiles-debian/test-home-volume.sh`. Real Podman and Docker tests (first start, same-version restart, new image, container recreation, ownership and volume migration) are still required before making the alternative image the default. This prototype derives from an already-built image, so earlier image layers still contain the baked home; directly integrating the seed into the primary Dockerfile is a separate follow-up.
