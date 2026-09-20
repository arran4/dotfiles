# Host Ollama and local coding agents

The development container can use an Ollama server running on the host without putting the Ollama daemon or model files inside the container. Its entrypoint seeds `~/.config/opencode/opencode.json` when that file does not already exist, selecting `ollama/qwen2.5-coder:7b` through the host bridge at `http://host.docker.internal:11434/v1`. An existing OpenCode config is left untouched by the normal entrypoint.

**Container variants:** The published `ghcr.io/arran4/dev-dotfiles-debian:latest` image still uses separate agent/forge persistence volumes. PR #464's locally built `dev-dotfiles-home-volume:trial` uses a versioned project-home seed and optionally one named home volume at `/home/user`; `/workspace` remains an independent directory. Build and launch that experimental variant using [README.md](README.md#quick-start-the-proposed-project-home) and [HOME-VOLUME.md](HOME-VOLUME.md). Do not use the trial's `DEV_HOME_VOLUME_INIT=1` instructions with the published image, or the legacy four separate agent/forge mount flags with the trial image.

With the experimental home image, OpenCode configuration, installed user-space agents, CLI session data and shell history live in the project home, whether it is a named volume or a disposable container layer. A same-version restart leaves them alone. A changed home seed may overwrite **matching seeded dotfiles/configuration** while leaving paths absent from that seed intact; the initializer explicitly protects known shell-history, GitHub/GitLab CLI and Codex/Antigravity auth/session paths on upgrades, but these exclusions do not cover every possible OpenCode, Zero, Aider, jcode or other agent credential/config path. Review and back up custom agent settings before an image upgrade. An existing container started again does not acquire a new image; recreate it with the same named home volume to apply a new version. See [HOME-VOLUME.md](HOME-VOLUME.md#paths-and-lifecycle).

## Host Ollama setup

Install Ollama on the host, make it listen beyond loopback, and pull the model once:

```sh
OLLAMA_HOST=0.0.0.0:11434 ollama serve
```

In another host shell:

```sh
ollama pull qwen2.5-coder:7b
```

For a systemd-managed Ollama service, make the listener persistent with an override:

```ini
[Service]
Environment="OLLAMA_HOST=0.0.0.0:11434"
```

Then reload and restart it:

```sh
sudo systemctl daemon-reload
sudo systemctl restart ollama
```

Binding Ollama to `0.0.0.0` exposes port 11434 on host interfaces, so use the host firewall to keep it limited to interfaces/networks that should be able to reach it. Ollama does not require an API key for its local server by default.

## Container-to-host address

Podman normally supplies both `host.containers.internal` and `host.docker.internal` inside a container. The seeded OpenCode config uses `host.docker.internal` so the same config also works with Docker Desktop.

On native Linux Docker, add the host-gateway mapping to the **outer `docker run` command**, for either image:

```sh
--add-host host.docker.internal:host-gateway
```

Do not put this flag inside the container or append it to `docker start`. For the experimental image use the `docker run` examples in [HOME-VOLUME.md](HOME-VOLUME.md#launch-with-docker); for the currently published image see the legacy flags in [README.md](README.md#currently-published-image-legacy-volume-layout). No host-network mode or host Docker socket passthrough is required.

From inside the container, verify the bridge and model API before starting an agent:

```sh
getent hosts host.docker.internal
curl -fsS http://host.docker.internal:11434/v1/models | jq .
```

## OpenCode

The entrypoint-created config is equivalent to:

```json
{
  "$schema": "https://opencode.ai/config.json",
  "provider": {
    "ollama": {
      "npm": "@ai-sdk/openai-compatible",
      "name": "Ollama (host)",
      "options": {
        "baseURL": "http://host.docker.internal:11434/v1"
      },
      "models": {
        "qwen2.5-coder:7b": {
          "name": "Qwen2.5 Coder 7B"
        }
      }
    }
  },
  "model": "ollama/qwen2.5-coder:7b"
}
```

OpenCode's `tools` setting is a top-level map of individual tool controls, not a model-level boolean. The config therefore leaves tools at OpenCode's defaults rather than adding `"tools": true` to the model entry.

Run:

```sh
opencode
```

If tool calling becomes unreliable with the local model, increase the Ollama context window rather than adding an OpenCode model-level `tools` flag.

## Optional additional agents

These are intentionally documented as user-space additions rather than baked into the base image. They change quickly and can be installed only in sandboxes where they are wanted. When using the experimental home image, install them under the home directory to retain them in a home volume; a global install into the container's writable system layer is lost on container removal or image replacement.

### Aider

Prefer an isolated install instead of installing `aider-chat` into the system Python environment:

```sh
pipx install aider-chat
```

or, if `uv` is available:

```sh
uv tool install --force --python python3.12 --with pip aider-chat@latest
```

A direct `pip install aider-chat` should be done inside a virtual environment. Aider has an Ollama-specific transport, so point that at the outer host without the `/v1` suffix:

```sh
export OLLAMA_API_BASE=http://host.docker.internal:11434
aider --model ollama_chat/qwen2.5-coder:7b
```

### Zero

This refers to `Gitlawb/zero`. Install its standalone Linux/macOS release with:

```sh
curl -fsSL https://raw.githubusercontent.com/Gitlawb/zero/main/scripts/install.sh | bash
```

Zero's Ollama provider accepts a base-URL override, which avoids its normal container-local `localhost` default:

```sh
zero setup ollama \
  --base-url http://host.docker.internal:11434/v1 \
  --model qwen2.5-coder:7b
```

Useful checks after setup are:

```sh
zero providers list
zero models list
zero doctor
```

### jcode

This refers to `1jehuang/jcode` (`jcode.sh`). Install it with:

```sh
curl -fsSL https://jcode.sh/install | bash
```

Inside the container, define the host Ollama endpoint as a no-auth OpenAI-compatible profile so jcode does not assume Ollama is on container localhost:

```sh
jcode provider add host-ollama \
  --base-url http://host.docker.internal:11434/v1 \
  --model qwen2.5-coder:7b \
  --no-api-key \
  --set-default
```

Then verify it with:

```sh
jcode --provider-profile host-ollama auth-test
```
