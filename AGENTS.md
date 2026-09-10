# Repo Guidelines for arran4/dotfiles

This repository stores dotfiles that are applied with [chezmoi](https://www.chezmoi.io/).

## Style
- Use **two spaces** for indentation and spaces over tabs.
- Ensure files end with a newline.
- Line endings must be LF.
- Trim trailing whitespace in all files except Markdown.

## Package Management
- **Do not** use scripting language package managers (like `npm`, `pip`, or `gem`) to install packages globally.
- Prefer OS-level package managers (e.g., `emerge` on Gentoo, `apt` on Debian, `pacman` on Arch, etc.) even if it means building a package from source manually.
- Flatpak is preferred over manual installations for desktop applications.
- `go install` may be used sparingly for user-level global installs (not system-wide).

## Hyprland keyboard shortcuts
- [`HYPRLAND_KEYBOARD_SHORTCUTS.md`](HYPRLAND_KEYBOARD_SHORTCUTS.md) is the human-readable shortcut summary.
- When adding, removing, renaming, or changing the meaning of a Hyprland keybinding, update that summary in the same change.
- Check both `dot_config/hypr/hyprland.lua.tmpl` and `dot_config/hypr/special_workspaces.lua`; shortcuts are defined in both, including group-management submap keys and special-workspace keys.

## Testing
Before submitting a pull request, attempt to apply the configuration using chezmoi:

```sh
yes "" | sh -c "$(curl -fsLS get.chezmoi.io)" -- init --no-tty --debug --apply arran4
```

If this command fails due to network restrictions, note this in the testing section of the PR.

## Pull Requests
Provide a concise summary of changes and cite any relevant files or lines.
