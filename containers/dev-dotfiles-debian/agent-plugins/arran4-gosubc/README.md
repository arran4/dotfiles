# gosubc agent plugin

This plugin provides the existing `gosubc` agent skill as an Agent Plugins 1.0 package. It describes how to use the `gosubc` executable; the plugin **does not install the executable** or start any MCP server.

The development image installs the executable and projects the skill to `/etc/codex/skills/gosubc` for Codex. For Antigravity App, CLI and IDE, the image deploys the plugin under `~/.gemini/config/plugins/arran4-gosubc`. The managed installer preserves manually installed or changed plugins.

To validate this package in a local checkout with Antigravity installed:

```sh
agy plugin validate --strict containers/dev-dotfiles-debian/agent-plugins/arran4-gosubc
agy plugin list --json
```

For a standalone installation outside the development image, run `agy plugin install /absolute/path/to/arran4-gosubc`. Do not install a second copy of the plugin into the same managed container home.

The skills-only directory `~/.gemini/antigravity-cli/skills/gosubc` is retired for *image-managed, unmodified* installations. User-owned or locally edited copies are preserved and may need manual removal to avoid duplicate skill discovery.

References:
- https://agent-plugins.org/specification
- https://antigravity.google/docs/build-plugins
- https://antigravity.google/docs/plugins
