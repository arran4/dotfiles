-- Keep all named special-workspace behavior together and render it directly
-- into hyprland.lua. This is a chezmoi source template, not a runtime Lua
-- module: hyprland.lua must remain self-contained when applied on its own.
do
  local workspaces = {
    { name = "music", key = "SUPER + M" },
    { name = "beeper", key = "SUPER + B" },
    { name = "terminal", key = "SUPER + grave" },
    { name = "scratchpad", key = "SUPER + D" },
    { name = "kjules", key = "SUPER + P" },
  }

  for _, workspace in ipairs(workspaces) do
    hl.bind(workspace.key, hl.dsp.workspace.toggle_special(workspace.name))
    hl.workspace_rule({ workspace = "special:" .. workspace.name, persistent = true })
  end

  -- Keep the convenient second terminal shortcut without duplicating the
  -- workspace definition itself.
  hl.bind("SUPER + T", hl.dsp.workspace.toggle_special("terminal"))

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
    kjules = {
      ["kjules"] = true,
      ["org.kde.kjules"] = true,
    },
  }

  -- Static rules cover the normal window-open path.
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
  hl.window_rule({
    match = { class = "^(kJules|kjules|org.kde.kjules)$" },
    workspace = "special:kjules",
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

    -- Beeper is Electron-based and can briefly expose a generic class while
    -- its final app id is still being set. Restrict the title fallback to
    -- generic Electron classes so browser pages mentioning Beeper are not
    -- captured.
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

  -- Fully initialized windows are the normal path. Listen for class changes
  -- too because Electron/Wayland clients may publish their final app id after
  -- mapping.
  hl.on("window.open", routeWindow)
  hl.on("window.class", routeWindow)

  -- Config reloads do not re-run static workspace effects for windows that are
  -- already open. Reconcile them immediately after an apply/reload.
  if type(hl.get_windows) == "function" then
    local windows = hl.get_windows()
    if windows ~= nil then
      for _, window in ipairs(windows) do
        routeWindow(window)
      end
    end
  end

  -- Startup for applications that are intentionally long-lived special
  -- workspace residents. kJules is routed when launched, but is not forced to
  -- autostart here.
  hl.on("hyprland.start", function()
    if terminal ~= "" then
      hl.exec_cmd(terminal, { workspace = "special:terminal silent" })
    end
    hl.exec_cmd("flatpak run com.spotify.Client", { workspace = "special:music silent" })
    hl.exec_cmd("flatpak run com.beeper.Beeper", { workspace = "special:beeper silent" })
  end)
end
