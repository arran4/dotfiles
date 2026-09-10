# Docker-in-Docker

`dev-dotfiles-debian` can run a Docker daemon inside the development container. This is real Docker-in-Docker: it does not bind-mount or proxy the host Docker socket.

The mode is opt-in because a nested Docker daemon needs additional privileges from the outer container runtime.

## Start a sandbox with DinD

Set the normal sandbox name first:

```sh
RAW_NAME=${SANDBOX_NAME:-$(basename "$PWD")}
SANDBOX_NAME=$(echo "$RAW_NAME" | sed 's/[^a-zA-Z0-9-]/-/g' | sed 's/-\{2,\}/-/g' | sed 's/^-//;s/-$//')
SANDBOX_NAME=${SANDBOX_NAME:-default-project}
```

### Rootless Podman

Rootless Podman remains the preferred outer engine. The outer container must be privileged for nested Docker, but rootless Podman still confines those privileges to the invoking user's user namespace rather than granting host root.

```sh
podman run --rm -it \
  --pull=always \
  --privileged \
  --name "dev-agent-${SANDBOX_NAME}" \
  --userns=keep-id:uid=1000,gid=1000 \
  --hostname "agent-${SANDBOX_NAME}" \
  --env DEV_DIND=1 \
  --env DEV_FORGE_VOLUME_INIT=1 \
  --workdir /workspace \
  --mount type=bind,src="$PWD",dst=/workspace,rw \
  --mount type=volume,src="dev-agent-${SANDBOX_NAME}-docker",dst=/var/lib/docker \
  --mount type=volume,src="dev-agent-${SANDBOX_NAME}-codex",dst=/home/user/.codex \
  --mount type=volume,src="dev-agent-${SANDBOX_NAME}-agy",dst=/home/user/.gemini \
  --mount type=volume,src="dev-agent-${SANDBOX_NAME}-gh",dst=/home/user/.config/gh \
  --mount type=volume,src="dev-agent-${SANDBOX_NAME}-glab",dst=/home/user/.config/glab-cli \
  ghcr.io/arran4/dev-dotfiles-debian:latest
```

### Docker

Docker can run the same mode:

```sh
docker run --rm -it \
  --pull=always \
  --privileged \
  --name "dev-agent-${SANDBOX_NAME}" \
  --hostname "agent-${SANDBOX_NAME}" \
  --env DEV_DIND=1 \
  --env DEV_FORGE_VOLUME_INIT=1 \
  --workdir /workspace \
  --mount type=bind,src="$PWD",dst=/workspace,rw \
  --mount type=volume,src="dev-agent-${SANDBOX_NAME}-docker",dst=/var/lib/docker \
  --mount type=volume,src="dev-agent-${SANDBOX_NAME}-codex",dst=/home/user/.codex \
  --mount type=volume,src="dev-agent-${SANDBOX_NAME}-agy",dst=/home/user/.gemini \
  --mount type=volume,src="dev-agent-${SANDBOX_NAME}-gh",dst=/home/user/.config/gh \
  --mount type=volume,src="dev-agent-${SANDBOX_NAME}-glab",dst=/home/user/.config/glab-cli \
  ghcr.io/arran4/dev-dotfiles-debian:latest
```

Prefer a rootless outer Docker daemon. Running this command against a rootful Docker daemon gives the outer container broad host-level privileges and materially weakens the sandbox boundary.

Do **not** add either of these mounts:

```text
-v /var/run/docker.sock:/var/run/docker.sock
-v /run/docker.sock:/run/docker.sock
```

When `DEV_DIND=1`, the entrypoint removes any pre-existing `/var/run/docker.sock` before starting its daemon. If that path is a bind mount and cannot be removed, startup fails rather than connecting to the host daemon.

The `dev-agent-${SANDBOX_NAME}-docker` volume is the nested daemon's own `/var/lib/docker`, so downloaded images, build cache and inner containers can persist independently of the host daemon.

## Verify it is genuinely nested

Inside the sandbox:

```sh
docker info
```

Then build and run an image without pulling a base image:

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

That exercises the inner daemon's build, image store and container runtime without depending on Docker Hub or another registry.
