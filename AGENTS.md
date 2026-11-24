# Repository guidelines for arran4/dotfiles

This repository stores dotfiles applied with [chezmoi](https://www.chezmoi.io/).

## Documentation ownership

- The root `README.md` is the first-stop personal bootstrap guide, historical orientation and configuration showcase. Keep copyable setup commands where they are genuinely useful; do not add generic tutorials or resolved migration instructions.
- Install user-facing command references as section 1 man pages under `home/dot_local/share/man/man1/`; use section 7 for configuration references under `home/dot_local/share/man/man7/`. Update relevant man pages in the same PR as changes to documented scripts.
- `man hyprland-keys` is the human-readable shortcut summary, stored in `home/dot_local/share/man/man7/hyprland-keys.7`. Maintain it when bindings change; the Lua configuration remains authoritative. Put only a useful shortcut selection in the root README.
- The existing `containers/dev-dotfiles-debian/README.md` remains the canonical operational guide for the image and launchers; its usage, persistence, security, authentication and migration instructions must reflect real code. The root README gives short commands and points to it or to `man run-dev-podman.sh` and `man run-dev-docker.sh`.
- Coding-agent implementation rules belong here. Avoid creating topical Markdown files for individual issues, experiments or PRs. Preserve truly necessary recovery and safety details while consolidating; do not copy whole command manuals into the root README.

- Maintain `home/dot_local/share/man/man7/agent-skills.7` as the index for the catalog at `containers/dev-dotfiles-debian/agent-skills/`; keep the list synchronized with each skill's `SKILL.md`. The skill files remain the source of truth for prompts, procedures and examples.

## Man-page and pipeline documentation maintenance

- Keep every maintained helper's section-1 manual synchronized with its implementation. Describe prerequisites, supported invocation and arguments, behaviour, examples, failure modes, and safety or persistence implications. Do not reduce manuals to a one-line command synopsis.
- Document repository-specific CI operations and non-secret credential requirements in `home/dot_local/share/man/man7/dotfiles-ci.7`. When workflows add or change an external token, signing key, deploy key, GitHub Actions permission or registry auth requirement, update the manual with the credential **name, purpose, scope, provisioning and rotation guidance**, never its secret value.
- Confirm examples against current scripts, and format-check roff where a formatter is available. Distinguish tests actually run from checks deferred to CI.

## Style

- Use **two spaces** for indentation and spaces over tabs.
- Ensure files end with a newline and use LF line endings.
- Trim trailing whitespace in all files except Markdown.

## Package management

- Do **not** use scripting-language package managers (such as `npm`, `pip`, or `gem`) to install packages globally.
- Prefer OS-level package managers (for example, `emerge`, `apt`, or `pacman`), even if a package must be built from source.
- Prefer Flatpak over manual installations for desktop applications.
- `go install` may be used sparingly for user-level installs, not system-wide installs.

## Hyprland keyboard shortcuts

- Maintain `home/dot_local/share/man/man7/hyprland-keys.7` in the same change as any keybinding addition, removal or meaning change.
- Check both `home/dot_config/hypr/hyprland.lua.tmpl` and `home/dot_config/hypr/special_workspaces.lua`; the latter includes group-management submaps and special workspaces.
- Check the runtime `hypr-cheatsheet` display for compatibility where Hyprland is available.

## Container-specific verification

- Before changing or documenting the launchers, inspect **both** `home/dot_local/bin/executable_run-dev-podman.sh` and `home/dot_local/bin/executable_run-dev-docker.sh`; keep the README's defaults, supported environment settings and persistence claims consistent with their actual behaviour. A resumed named container does not pick up a new image or new mount options.
- Verify the published image separately from the optional, locally built project-home image. Do not imply that merging the experimental Dockerfile publishes it as `:latest`.
- When changing persistence, test or explicitly document what survives stop/start versus container removal/recreation; do not recommend deleting volumes as part of a routine upgrade. Keep nested Docker data lifetime independent of the home and workspace lifetime.
- For relevant container changes, run `sh containers/dev-dotfiles-debian/test-home-volume.sh`, syntax-check both launchers with `sh -n`, and run any applicable ShellCheck/configuration and image-build checks. State clearly which live Docker/Podman scenarios were or were not verified.

## General testing

Before submitting a pull request, attempt to apply the configuration using chezmoi:

```sh
yes "" | sh -c "$(curl -fsLS get.chezmoi.io)" -- init --no-tty --debug --apply arran4
```

If this fails because the network or execution environment is restricted, document that in the PR testing section. Never infer that an unrun check passed.

## Pull requests

Provide a concise summary of changes and cite relevant files or lines. Submit a PR for the work and leave merging to the repository maintainer.
