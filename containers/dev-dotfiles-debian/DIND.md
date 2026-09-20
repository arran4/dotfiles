# Docker-in-Docker

`dev-dotfiles-debian` can start its own Docker daemon inside a development container with `DEV_DIND=1`. It does **not** bind mount or proxy the host Docker/Podman socket. This mode requires extra privileges and is separate from the ordinary, unprivileged sandbox described in [README.md](README.md).

**Which image?** Published `ghcr.io/arran4/dev-dotfiles-debian:latest` still uses separate `-codex`, `-agy`, `-gh` and `-glab` volumes. PR #464 adds an **opt-in local image**, `dev-dotfiles-home-volume:trial`, with one versioned home volume instead of those four mounts. Build that variant first using [HOME-VOLUME.md](HOME-VOLUME.md#build-the-alternative-image); do not run the experimental entrypoint/flags against published `:latest`.

## Naming and privilege boundary

In a host shell, select a unique sandbox name; use a trial name when evaluating the new image so it does not collide with a running legacy container:

```sh
RAW_NAME=${SANDBOX_NAME:-$(basename "$PWD")}
SANDBOX_NAME=$(printf '%s' "$RAW_NAME" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9-]/-/g;s/-\{2,\}/-/g;s/^-//;s/-$//')
SANDBOX_NAME=${SANDBOX_NAME:-default-project}
```

Rootless Podman is preferred: the outer `--privileged` is still confined to the invoking user's user namespace. Against a **rootful** Docker daemon, `--privileged` grants broad host-level capabilities and substantially weakens isolation. Neither engine should be given a bind mount of `/var/run/docker.sock`, `/run/docker.sock`, or the host Podman socket. When `DEV_DIND=1`, the entrypoint refuses to reuse an existing non-removable socket mount.

## Nested Docker data lifetime

The nested daemon stores images, build cache, and its inner container state under `/var/lib/docker`. **No separate Docker-data volume is required** for the normal experimental launch. Without a mount there, the data stays in the outer container's writable layer: it survives `stop`/`start` of that same container but is discarded when the outer container is removed or recreated. A newer image does not carry that old cache or inner-container state forward. This is distinct from `/home/user` and `/workspace`, which follow their own mount settings.

If you deliberately need Docker images, cache, or inner containers to survive *outer-container recreation*, add this optional mount to the Podman or Docker invocation:

```sh
  --mount "type=volume,src=dev-agent-${SANDBOX_NAME}-docker,dst=/var/lib/docker" \
```

Keep that volume separate from the home volume. An ordinary writable-layer directory is **not erased by a simple stop**. A `--tmpfs` mount is a different, stop-volatile option, but its size and Docker storage-driver compatibility must be tested before use; it is not the default described here. Existing `-docker` volumes from earlier invocations are not deleted or migrated automatically.

## Experimental project-home image: rootless Podman

After building the trial image, start with a host checkout and **one named volume for home**. Nested Docker state is kept only in the outer container's writable layer:

```sh
workspace=$(pwd -P)
podman run -it --name "dev-agent-${SANDBOX_NAME}-home-trial" --restart=no \
  --privileged --userns=keep-id:uid=1000,gid=1000 \
  --hostname "agent-${SANDBOX_NAME}" \
  --env DEV_DIND=1 --env DEV_HOME_VOLUME_INIT=1 \
  --workdir /workspace \
  --mount "type=bind,src=${workspace},dst=/workspace,rw" \
  --mount "type=volume,src=dev-agent-${SANDBOX_NAME}-home,dst=/home/user" \
  dev-dotfiles-home-volume:trial
```

To use an independently persistent, filesystem-disconnected project, replace the bind mount with `--mount "type=volume,src=dev-agent-${SANDBOX_NAME}-workspace,dst=/workspace"`. That adds a separate **workspace** volume. You may instead omit the workspace mount to import a repository into the container's writable `/workspace`; copy it out before removing or upgrading that container. Omit the home volume too only for a fully disposable experiment; retaining nested Docker storage remains an independent, optional choice. Do not add the old separate agent/forge volume mounts on top of a project home.

## Experimental project-home image: Docker

Build the same trial image with `docker build` as described in [HOME-VOLUME.md](HOME-VOLUME.md#build-the-alternative-image). For a Docker daemon where the image's UID/GID `1000:1000` can write the host checkout:

```sh
workspace=$(pwd -P)
docker run -it --name "dev-agent-${SANDBOX_NAME}-home-trial" --restart=no \
  --privileged --hostname "agent-${SANDBOX_NAME}" \
  --env DEV_DIND=1 --env DEV_HOME_VOLUME_INIT=1 \
  --workdir /workspace \
  --mount "type=bind,src=${workspace},dst=/workspace,rw" \
  --mount "type=volume,src=dev-agent-${SANDBOX_NAME}-home,dst=/home/user" \
  dev-dotfiles-home-volume:trial
```

Docker does not support Podman's `--userns=keep-id` flag. Check bind-mount ownership with rootless Docker. Use the same workspace-volume or writable-container alternatives described in the Podman section. If accessing host Ollama with native Linux Docker, add `--add-host host.docker.internal:host-gateway`.

For either engine, `start -ai` resumes the **same image**, not a newer one. To apply an updated versioned home seed, stop the container, preserve its workspace if it is on the writable layer, remove **only the container object**, and recreate using the new locally built image with the same home volume name. Nested Docker cache is intentionally discarded on recreation unless you opted into the separate Docker-data volume. See [HOME-VOLUME.md](HOME-VOLUME.md#paths-and-lifecycle). Do not delete existing volumes as part of an image upgrade.

## Currently published image: legacy invocation

Until the home-volume variant is integrated into the primary image, the published tag still needs `DEV_FORGE_VOLUME_INIT=1` and the separate four agent/forge volumes. The following mount flags apply to **either** the original rootless Podman or Docker `run` command, in addition to `--privileged --env DEV_DIND=1 --workdir /workspace` and the engine-specific options described above:

```sh
--env DEV_FORGE_VOLUME_INIT=1 \
--mount "type=bind,src=$(pwd -P),dst=/workspace,rw" \
--mount "type=volume,src=dev-agent-${SANDBOX_NAME}-codex,dst=/home/user/.codex" \
--mount "type=volume,src=dev-agent-${SANDBOX_NAME}-agy,dst=/home/user/.gemini" \
--mount "type=volume,src=dev-agent-${SANDBOX_NAME}-gh,dst=/home/user/.config/gh" \
--mount "type=volume,src=dev-agent-${SANDBOX_NAME}-glab,dst=/home/user/.config/glab-cli"
```

Use `ghcr.io/arran4/dev-dotfiles-debian:latest` at the end of that **legacy-only** invocation. The Docker-data volume shown earlier is optional with the published image too; add it only if nested images and caches must outlive outer-container recreation. To replace the bind mount with a legacy persistent workspace volume, use `DEV_VOLUME_INIT=1` and `--mount "type=volume,src=dev-agent-${SANDBOX_NAME}-workspace,dst=/workspace"`. Legacy data does not appear automatically in the trial image; see the deliberate migration guidance in [HOME-VOLUME.md](HOME-VOLUME.md#migration-and-cleanup).

## Verify nested Docker

Inside the sandbox:

```sh
docker info
```

Then build and run a scratch-based image without pulling from a registry:

```sh
tmp=$(mktemp -d)
cat > "$tmp/main.go" <<'EOF'
package main
func main() {}
EOF
CGO_ENABLED=0 go build -o "$tmp/smoke" "$tmp/main.go"
cat > "$tmp/Dockerfile" <<'EOF'
FROM scratch
COPY smoke /smoke
ENTRYPOINT ["/smoke"]
EOF
docker build -t dev-dind-smoke "$tmp"
docker run --rm dev-dind-smoke
rm -rf "$tmp"
```

This verifies the inner daemon's build, image store and container runtime without contacting Docker Hub or another registry.
