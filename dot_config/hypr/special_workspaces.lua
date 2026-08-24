-- Keep long-lived applications attached to their named special workspaces.
--
-- Static workspace window rules are useful for the common case, but they only
-- apply when a window is created. They also use the initial class for static
-- effects, which can miss Electron applications that publish their final class
-- later. This module therefore combines static rules, class-change handling,
-- and reconciliation of already-open windows on config reload.

local classRoutes = {
  music = {
    ["spotify"] = true,
    ["org.spotify.client"] = true,
    ["com.spotify.client"] = true,
  },
  beeper = {
    ["beeper"] = true,
    ["beepertexts"] = true,
    ["com.beeper.beeper"] = true,
  },
  terminal = {
    ["alacritty"] = true,
    ["foot"] = true,
    ["footclient"] = true,
    ["kitty"] = true,
    ["com.mitchellh.ghostty"] = true,
    ["ghostty"] = true,
    ["org.wezfurlong.wezterm"] = true,
    ["wezterm"] = true,
    ["terminator"] = true,
    ["konsole"] = true,
    ["org.kde.konsole"] = true,
    ["xfce4-terminal"] = true,
    ["gnome-terminal"] = true,
    ["gnome-terminal-server"] = true,
    ["org.gnome.terminal"] = true,
    ["org.gnome.console"] = true,
    ["mate-terminal"] = true,
    ["lxterminal"] = true,
    ["urxvt"] = true,
    ["rxvt-unicode"] = true,
    ["rxvt"] = true,
    ["xterm"] = true,
  },
}

-- Keep static rules for the normal window-open path. The event routing below
-- supplements these rules for late class changes and existing windows.
hl.window_rule({
  match = { class = "^(Spotify|spotify|org.spotify.Client|com.spotify.Client)$" },
  workspace = "special:music",
})
hl.window_rule({
  match = { class = "^(Beeper|beeper|BeeperTexts|beepertexts|com.beeper.Beeper|com.beeper.beeper)$" },
  workspace = "special:beeper",
})
hl.window_rule({
  match = { class = "^(Alacritty|alacritty|foot|footclient|kitty|com.mitchellh.ghostty|ghostty|org.wezfurlong.wezterm|wezterm|terminator|konsole|org.kde.konsole|xfce4-terminal|gnome-terminal|gnome-terminal-server|org.gnome.terminal|org.gnome.console|mate-terminal|lxterminal|URxvt|urxvt|rxvt-unicode|rxvt|XTerm|xterm)$" },
  workspace = "special:terminal",
})

local function lower(value)
  if type(value) ~= "string" then
    return ""
  end
  return value:lower()
end

local function workspaceForWindow(window)
  if window == nil then
    return nil
  end

  local class = lower(window.class)
  for workspace, classes in pairs(classRoutes) do
    if classes[class] then
      return workspace
    end
  end

  -- Beeper is Electron-based and can briefly expose a generic class while its
  -- final app id is still being set. Restrict the title fallback to generic
  -- Electron classes so browser pages mentioning Beeper are not captured.
  if class == "" or class == "electron" then
    local title = lower(window.title)
    if title:find("beeper", 1, true) then
      return "beeper"
    end
  end

  return nil
end

local function routeWindow(window)
  local workspace = workspaceForWindow(window)
  if workspace == nil then
    return
  end

  hl.dispatch(hl.dsp.window.move({
    workspace = "special:" .. workspace,
    follow = false,
    window = window,
  }))
end

-- Fully initialized windows are the normal path. Listen for class changes too,
-- because Electron/Wayland clients may publish their final app id after mapping.
hl.on("window.open", routeWindow)
hl.on("window.class", routeWindow)

-- Config reloads do not re-run static workspace effects for windows that are
-- already open. Reconcile them so Meta+M/B/T works immediately after an apply.
if type(hl.get_windows) == "function" then
  local windows = hl.get_windows()
  if windows ~= nil then
    for _, window in ipairs(windows) do
      routeWindow(window)
    end
  end
end

return {
  route_window = routeWindow,
  workspace_for_window = workspaceForWindow,
}
