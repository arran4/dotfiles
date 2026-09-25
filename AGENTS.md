# Repository guidelines for arran4/dotfiles

This repository stores dotfiles applied with [chezmoi](https://www.chezmoi.io/).

## Documentation ownership

- **Human-facing setup and operations belong in the existing `README.md`.** The root `README.md` is the entry point and links to substantial component guides; `containers/dev-dotfiles-debian/README.md` is the single operational source for the development container. When changing Docker, Podman, authentication, persistence, launch scripts, image building, release behaviour, or local AI, update the corresponding section in that container README **in the same change**.
- **Instructions for coding agents belong in this `AGENTS.md`** (or a scoped `AGENTS.md` if there is a concrete need for directory-specific instructions). Keep implementation constraints, verification steps and documentation maintenance policy here, rather than in a new topical `*.md` guide.
- Do not create a separate Markdown guide for each feature, issue, PR, or experiment. First extend the appropriate README section or this AGENTS file, consolidate duplicated instructions, and update existing links. Create another Markdown file only for a distinct functional format (such as a template), or a substantial standalone reference whose purpose and discovery path are explained from the README. Never use an extra Markdown file merely because an agent needs to read it.
- Avoid copying whole container launch commands into the root README; link to the canonical container instructions. Distinguish *repository-merged* features from *published image* features, and do not write prospective PR status as current fact. If an old documentation file is removed, fix links in scripts, READMEs, CI, and other maintained files. Preserve operational details when consolidating; do not delete safety or migration guidance just to reduce the file count.
- The root `HYPRLAND_KEYBOARD_SHORTCUTS.md` is an on-demand, human-readable shortcut reference linked from the root README. Keep it synchronized with the actual bindings, rather than treating it as a competing general documentation guide.

## Style

- Use **two spaces** for indentation and spaces over tabs.
- Ensure files end with a newline and use LF line endings.
- Trim trailing whitespace in all files except Markdown.

## Package management

- Do **not** use scripting-language package managers (such as `npm`, `pip`, or `gem`) to install packages globally.
- Prefer OS-level package managers (for example, `emerge`, `apt`, or `pacman`), even if a package must be built from source.
- Prefer Flatpak over manual installations for desktop applications.
- Keep Flatpak application inventories in `README.md`, `.chezmoi.toml.tmpl`, and the chezmoi Flatpak installer synchronized. Bitwarden (`com.bitwarden.desktop`) is part of the required Flatpak set.
- `go install` may be used sparingly for user-level installs, not system-wide installs.

## Hyprland keyboard shortcuts

- [`HYPRLAND_KEYBOARD_SHORTCUTS.md`](HYPRLAND_KEYBOARD_SHORTCUTS.md) is the human-readable shortcut summary.
- When adding, removing, renaming, or changing the meaning of a binding, update the shortcut summary in the same change.
- Check both `dot_config/hypr/hyprland.lua.tmpl` and `dot_config/hypr/special_workspaces.lua`; shortcuts are defined in both, including group-management submap and special-workspace keys.

## Container-specific verification

- Before changing or documenting the launchers, inspect **both** `dot_local/bin/executable_run-dev-podman.sh` and `dot_local/bin/executable_run-dev-docker.sh`; keep the README's defaults, supported environment settings and persistence claims consistent with their actual behaviour. A resumed named container does not pick up a new image or new mount options.
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
