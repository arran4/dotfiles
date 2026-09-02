# Hyprland keyboard shortcuts

This is the human-readable summary of the Hyprland shortcuts configured by this repository.

The source of truth remains:

- [`dot_config/hypr/hyprland.lua.tmpl`](dot_config/hypr/hyprland.lua.tmpl) for the main bindings.
- [`dot_config/hypr/special_workspaces.lua`](dot_config/hypr/special_workspaces.lua) for special workspaces and window-group bindings.
- [`dot_local/bin/executable_hypr-cheatsheet.tmpl`](dot_local/bin/executable_hypr-cheatsheet.tmpl) for the runtime cheatsheet populated from `hyprctl binds`.

> **Maintenance:** when a Hyprland binding is added, removed, renamed, or changes meaning, update this document in the same change. `AGENTS.md` also carries this instruction for coding agents/LLMs.

## Notation

- **Super** means the Meta/Windows key.
- **Caelestia** bindings are only registered when `hyprland_features = "quickshell"`.
- **Fallback** bindings are used when the Caelestia/Quickshell profile is not active.
- Some launch shortcuts only exist when the corresponding executable is available.

## Launchers, applications, and special workspaces

| Shortcut | Action | Notes |
| --- | --- | --- |
| `Super` (release) | Open the Caelestia launcher | Caelestia only; a plain Super tap/release. |
| `Super+Return` | Open a terminal | Uses the preferred detected terminal. |
| `Ctrl+Super+T` | Open an additional terminal | Direct terminal launcher. |
| `Super+T` | Open a normal terminal | On modern Hyprland; deliberately outside the special terminal workspace. |
| `Super+grave` | Toggle/open the special terminal workspace | `grave` is the backtick key. |
| `Super+M` | Toggle/open Spotify special workspace | Routes/launches Spotify. |
| `Super+B` | Toggle/open Beeper special workspace | Routes/launches Beeper. |
| `Super+D` | Toggle the scratchpad special workspace | Does not automatically launch an application. |
| `Super+I` | Toggle/open KMagMux special workspace | Routes/activates KMagMux. |
| `Super+J` | Toggle/open kJules special workspace | Routes/activates kJules. |
| `Super+Shift+J` | Start a new kJules session | Runs `kjules --new-session`. |
| `Super+Shift+_` | Toggle/open which_browser special workspace | Config key name is `underscore`. |
| `Super+A` | Open Anytype | Only when Anytype is configured. |
| `Super+.` | Open the Plasma emoji picker | Only when `plasma-emojier` is available. |
| `Super+V` | Open clipboard history | Prefers Caelestia clipboard; otherwise cliphist/clipse fallbacks. |
| `Super+Y` | Cycle Hyprland layout | Runs `hypr-cycle-layout`. |
| `Super+F5` | Set/change wallpaper | Runs `set-wallpaper`. |

## Caelestia / shell controls

These bindings are only present in the Quickshell/Caelestia profile.

| Shortcut | Action |
| --- | --- |
| `Super+Alt+Delete` | Open the Caelestia session/power menu. |
| `Super+N` | Open the notification sidebar. |
| `Super+Shift+N` | Clear notifications. |
| `Super+K` | Open Caelestia `showall`. |
| `Super+L` | Lock through Caelestia. |
| `Super+Alt+L` | Start the Caelestia shell daemon. |
| `Ctrl+Super+Shift+R` | Kill the Caelestia shell on key release. |
| `Ctrl+Super+Alt+R` | Kill and restart the Caelestia shell on key release. |
| `Super+/` | Open the runtime Hyprland cheatsheet. |
| `Super+Shift+/` (`Super+?`) | Open the runtime Hyprland cheatsheet. |

Without the Caelestia profile, `Super+L` invokes the configured lock command instead.

## Windows and layout

| Shortcut | Action |
| --- | --- |
| `Super+Shift+Q` | Ask the focused window to terminate with signal 15. |
| `Super+Shift+W` | Close the focused window. |
| `Super+Ctrl+Alt+Escape` | Force-kill the focused window. |
| `Super+F` | Toggle fullscreen. |
| `Super+Shift+Space` | Toggle floating. |
| `Super+Alt+Space` | Toggle floating. |
| `Alt+Tab` | Cycle to the next window and raise it. |
| `Alt+Shift+Tab` | Cycle to the previous window. |

### Focus a neighbouring window

| Shortcut | Direction |
| --- | --- |
| `Super+Left` or `Super+H` | Left |
| `Super+Right` | Right |
| `Super+Up` | Up |
| `Super+Down` | Down |

### Move the focused window

| Shortcut | Direction |
| --- | --- |
| `Super+Shift+Left` or `Super+Shift+H` | Left |
| `Super+Shift+Right` or `Super+Shift+L` | Right |
| `Super+Shift+Up` or `Super+Shift+K` | Up |
| `Super+Shift+Down` | Down |

## Workspaces

| Shortcut | Action |
| --- | --- |
| `Super+1` … `Super+9` | Focus workspace 1 … 9. |
| `Super+0` | Focus an empty workspace. |
| `Super+Shift+1` … `Super+Shift+9` | Move the focused window to workspace 1 … 9. |
| `Super+Shift+0` | Move the focused window to an empty workspace. |
| `Super+Ctrl+Left` | Focus the previous workspace. |
| `Super+Ctrl+Right` | Focus the next workspace. |
| `Super+Shift+Ctrl+Left` | Move the focused window to the previous workspace. |
| `Super+Shift+Ctrl+Right` | Move the focused window to the next workspace. |

Relative workspace moves use the window-relocation helper when available: the moved window remains temporarily "picked up" until Super is released.

## Window groups / tabs

| Shortcut | Action |
| --- | --- |
| `Super+Ctrl+Up` | Previous window/tab in the current group. |
| `Super+Ctrl+Down` | Next window/tab in the current group. |
| `Super+G` | Enter one-shot group-management mode. |

After pressing `Super+G`, use one of these keys. The action exits group-management mode afterwards unless cancelled.

| Key in group-management mode | Action |
| --- | --- |
| `H` or `Left` | Group with the left neighbour. |
| `J` or `Down` | Group with the lower neighbour. |
| `K` or `Up` | Group with the upper neighbour. |
| `L` or `Right` | Group with the right neighbour. |
| `E` | Extract the window from its group. |
| `N` | Next window in the group. |
| `P` | Previous window in the group. |
| `F` | Move the window forward in the group. |
| `B` | Move the window backward in the group. |
| `T` | Toggle window grouping. |
| `Escape` | Cancel group-management mode. |

## Screenshots

### Caelestia profile

| Shortcut | Action |
| --- | --- |
| `Print` | Run the Caelestia screenshot flow. |
| `Super+Shift+S` | Invoke Caelestia screenshot-freeze selection. |
| `Super+Shift+Alt+S` | Invoke the Caelestia screenshot action. |

### Non-Caelestia fallback

These require the configured screenshot tools. The same logical bindings are used with either `hyprshot` or the `grim`/`slurp` fallback.

| Shortcut | Action |
| --- | --- |
| `Super+Print` | Capture a window. |
| `Shift+Print` | Capture the screen. |
| `Super+Shift+Print` | Capture a selected region. |
| `Super+Ctrl+Print` | Capture a window. |

## Screen recording

These bindings are present when `wf-recorder` and `slurp` are configured.

| Shortcut | Action |
| --- | --- |
| `Super+Shift+R` | Record a selected region. |
| `Super+Alt+R` | Start a normal/full-output recording. |
| `Super+Ctrl+R` | Record a selected window. |

## Audio, media, and brightness

| Shortcut | Action | Notes |
| --- | --- | --- |
| `XF86AudioRaiseVolume` | Raise volume by 1%. | Repeats while held. |
| `XF86AudioLowerVolume` | Lower volume by 1%. | |
| `XF86AudioMute` | Toggle output mute. | |
| `Super+Shift+M` | Toggle output mute. | |
| `XF86MonBrightnessUp` | Increase brightness. | Caelestia only. |
| `XF86MonBrightnessDown` | Decrease brightness. | Caelestia only. |
| `Ctrl+Super+Space` | Play/pause media. | Caelestia only. |
| `Ctrl+Super+=` | Next media item. | Caelestia only. |
| `Ctrl+Super+-` | Previous media item. | Caelestia only. |
| `XF86AudioPlay` / `XF86AudioPause` | Play/pause media. | Caelestia handles these in that profile; `playerctl` is the fallback. |
| `XF86AudioNext` | Next media item. | Caelestia or `playerctl` fallback. |
| `XF86AudioPrev` | Previous media item. | Caelestia or `playerctl` fallback. |
| `XF86AudioStop` | Stop media. | Caelestia only. |

## Mouse bindings related to keyboard modifiers

These are not keyboard shortcuts, but they share the same Super-based interaction model.

| Input | Action |
| --- | --- |
| `Super+Left mouse button` | Drag/move a window. |
| `Super+Right mouse button` | Resize a window. |
| `Super+mouse wheel up` | Move the focused window to the previous workspace. |
| `Super+mouse wheel down` | Move the focused window to the next workspace. |

## Runtime verification

`Super+/` or `Super+?` runs `hypr-cheatsheet`, which reads the bindings currently registered by Hyprland with:

```sh
hyprctl binds -j
```

That runtime view shows what is active on the current host. This Markdown file explains the shortcuts and their purpose, including conditional bindings that may not be active on every machine.
