-- Keep all named special-workspace behavior together.
--
-- This is a runtime Hyprland Lua module deployed alongside hyprland.lua and
-- the local_*.lua machine modules. hyprland.lua loads it defensively and calls
-- setup() with the small amount of shared state it needs.

local M = {}

local workspaces = {
  { name = "music", key = "SUPER + M" },
  { name = "beeper", key = "SUPER + B" },
  { name = "terminal", key = "SUPER + grave" },
  { name = "scratchpad", key = "SUPER + D" },
  { name = "kjules", key = "SUPER + J" },
}

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
  terminal = {}, -- Populated dynamically in setup
  kjules = {
    ["kjules"] = true,
    ["org.kde.kjules"] = true,
  },
}

local kwalletStartup = [[
if command -v pam_kwallet_init >/dev/null 2>&1; then
  pam_kwallet_init
elif [ -x /usr/libexec/pam_kwallet_init ]; then
  /usr/libexec/pam_kwallet_init
elif [ -x /usr/lib/pam_kwallet_init ]; then
  /usr/lib/pam_kwallet_init
elif [ -x /usr/lib64/libexec/pam_kwallet_init ]; then
  /usr/lib64/libexec/pam_kwallet_init
elif [ -x /usr/lib64/pam_kwallet_init ]; then
  /usr/lib64/pam_kwallet_init
fi
if command -v kwalletd6 >/dev/null 2>&1; then
  exec kwalletd6
fi
]]

local function lower(value)
  if type(value) ~= "string" then
    return ""
  end
  return value:lower()
end

local regexMetacharacters = {
  ["\\"] = true,
  ["|"] = true,
  ["{"] = true,
  ["}"] = true,
  ["."] = true,
  ["+"] = true,
  ["*"] = true,
  ["?"] = true,
  ["("] = true,
  [")"] = true,
  ["["] = true,
  ["]"] = true,
  ["^"] = true,
  ["$"] = true,
}

local function escapeRegexAlternative(value)
  return (value:gsub(".", function(character)
    if regexMetacharacters[character] then
      return "\\" .. character
    end
    return character
  end))
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

local function specialName(workspace)
  if workspace == nil then
    return ""
  end
  local name = lower(workspace.name)
  if name:sub(1, 8) == "special:" then
    return name:sub(9)
  end
  return name
end

function M.setup(options)
  options = options or {}
  local terminal = options.terminal or { path = "", classes = {} }
  if type(terminal) == "string" then
    terminal = { path = terminal, classes = {} }
  end

  local terminalClasses = {}
  local terminalRegexGroups = {}
  if type(terminal.classes) == "table" then
    for _, class in ipairs(terminal.classes) do
      terminalClasses[lower(class)] = true

      table.insert(terminalRegexGroups, escapeRegexAlternative(class))
    end
  end
  classRoutes.terminal = terminalClasses

  -- Modern Hyprland exposes enough runtime state to make the application
  -- workspaces behave as show-or-create launchers instead of blind toggles.
  -- Keep the direct-toggle fallback for older runtimes (and simple API mocks).
  local smartManagedWorkspaces =
    type(hl.get_active_special_workspace) == "function"
    and type(hl.get_workspace_windows) == "function"
    and type(hl.get_windows) == "function"

  local pendingSpecialTerminal = false

  local function routeWindow(window)
    local workspace = workspaceForWindow(window)
    if workspace == nil then
      return
    end

    -- A terminal is special only when it was explicitly requested as the
    -- special terminal. Ordinary terminal launches (for example
    -- Meta+Shift+T) must remain on the normal workspace instead of being
    -- captured by class.
    if smartManagedWorkspaces and workspace == "terminal" then
      if not pendingSpecialTerminal then
        return
      end
      pendingSpecialTerminal = false
    end

    hl.dispatch(hl.dsp.window.move({
      workspace = "special:" .. workspace,
      follow = false,
      window = window,
    }))
  end

  local function isSpecialActive(name)
    if not smartManagedWorkspaces then
      return false
    end
    return specialName(hl.get_active_special_workspace()) == lower(name)
  end

  local function hasSpecialTerminal()
    if not smartManagedWorkspaces then
      return false
    end

    local windows = hl.get_workspace_windows("special:terminal") or {}
    for _, window in ipairs(windows) do
      if classRoutes.terminal[lower(window.class)] then
        return true
      end
    end
    return false
  end

  local function routeExistingApplication(name)
    if not smartManagedWorkspaces then
      return false
    end

    if name == "terminal" then
      return hasSpecialTerminal()
    end

    local found = false
    for _, window in ipairs(hl.get_windows() or {}) do
      if workspaceForWindow(window) == name then
        found = true
        routeWindow(window)
      end
    end
    return found
  end

  local function expirePendingTerminal()
    if type(hl.timer) == "function" then
      hl.timer(function()
        pendingSpecialTerminal = false
      end, { timeout = 5000, type = "oneshot" })
    end
  end

  local function launchManagedApplication(name)
    if name == "terminal" then
      if terminal.path == "" then
        return
      end
      pendingSpecialTerminal = true
      expirePendingTerminal()
      -- The workspace exec rule is the normal path; pendingSpecialTerminal is
      -- a fallback for terminals that fork/daemonize and lose the spawning PID.
      hl.exec_cmd(terminal.path, { workspace = "special:terminal silent" })
      return
    end

    if name == "music" then
      -- Spotify is single-instance. Re-running the Flatpak also acts as an
      -- activation request when it is still running but has no mapped window.
      hl.exec_cmd("flatpak run com.spotify.Client", { workspace = "special:music silent" })
      return
    end

    if name == "beeper" then
      -- Beeper can close its main window to the tray. Re-running the Flatpak
      -- asks the existing single-instance app to present a window again.
      hl.exec_cmd("flatpak run com.beeper.Beeper", { workspace = "special:beeper silent" })
    end
  end

  local function toggleManagedWorkspace(name)
    -- The same key always hides the workspace when it is currently visible.
    if isSpecialActive(name) then
      hl.dispatch(hl.dsp.workspace.toggle_special(name))
      return
    end

    -- If a mapped app window already exists, reclaim it into its special
    -- workspace before showing that workspace. If there is no mapped window,
    -- show the workspace and launch/activate the application afterwards. This
    -- also covers Spotify/Beeper processes that are currently tray-only.
    local hasWindow = routeExistingApplication(name)
    hl.dispatch(hl.dsp.workspace.toggle_special(name))
    if not hasWindow then
      launchManagedApplication(name)
    end
  end

  for _, workspace in ipairs(workspaces) do
    local action = hl.dsp.workspace.toggle_special(workspace.name)
    if smartManagedWorkspaces
      and (workspace.name == "music" or workspace.name == "beeper" or workspace.name == "terminal") then
      action = function()
        toggleManagedWorkspace(workspace.name)
      end
    end

    hl.bind(workspace.key, action)
    hl.workspace_rule({ workspace = "special:" .. workspace.name, persistent = true })
  end

  -- Keep the convenient second terminal shortcut, with show-or-create behavior
  -- on modern Hyprland.
  if smartManagedWorkspaces then
    hl.bind("SUPER + T", function()
      toggleManagedWorkspace("terminal")
    end)
  else
    hl.bind("SUPER + T", hl.dsp.workspace.toggle_special("terminal"))
  end

  -- Explicitly launch a new normal terminal without involving special:terminal.
  if terminal.path ~= "" then
    hl.bind("SUPER + SHIFT + T", function()
      hl.exec_cmd(terminal.path)
    end)
  end

  -- Explicitly launch a new kjules session without involving special:kjules routing immediately.
  -- This forwards the request to an already-running instance via DBus/IPC or starts a new one.
  hl.bind("SUPER + SHIFT + J", function()
    hl.exec_cmd("kjules --new-session")
  end)

  -- Static rules cover normal app window-open paths. On modern Hyprland the
  -- terminal is intentionally excluded: only the terminal explicitly launched
  -- for special:terminal should be captured.
  hl.window_rule({
    match = { class = "^(Spotify|spotify|org.spotify.Client|com.spotify.Client)$" },
    workspace = "special:music",
  })
  hl.window_rule({
    match = { class = "^(Beeper|beeper|BeeperTexts|beepertexts|com.beeper.Beeper|com.beeper.beeper)$" },
    workspace = "special:beeper",
  })
  if not smartManagedWorkspaces then
    if #terminalRegexGroups > 0 then
      local regex = "^(" .. table.concat(terminalRegexGroups, "|") .. ")$"
      hl.window_rule({
        match = { class = regex },
        workspace = "special:terminal",
      })
    end
  end
  hl.window_rule({
    match = { class = "^(kJules|kjules|org.kde.kjules)$" },
    workspace = "special:kjules",
  })

  -- Fully initialized windows are the normal path. Listen for class changes
  -- too because Electron/Wayland clients may publish their final app id after
  -- mapping.
  hl.on("window.open", routeWindow)
  hl.on("window.class", routeWindow)

  -- Config reloads do not re-run static workspace effects for windows that are
  -- already open. Reconcile them immediately after an apply/reload. On modern
  -- Hyprland ordinary terminals are deliberately left wherever the user put
  -- them; an existing special terminal is already in special:terminal.
  if type(hl.get_windows) == "function" then
    local windows = hl.get_windows()
    if windows ~= nil then
      for _, window in ipairs(windows) do
        routeWindow(window)
      end
    end
  end

  -- Start session services and applications that are intentionally long-lived
  -- special-workspace residents. kJules remains a blind Meta+J toggle for now;
  -- once it is reliably single-instance it can use the show-or-create path too.
  hl.on("hyprland.start", function()
    -- pam_kwallet_init forwards PAM-provided unlock data when it exists; it
    -- does not itself start the wallet daemon. Run the handoff first and then
    -- ensure kwalletd6 is started. The common lib/libexec locations cover
    -- Gentoo and other distributions where pam_kwallet_init is outside PATH.
    hl.exec_cmd(kwalletStartup)

    if terminal.path ~= "" then
      if smartManagedWorkspaces then
        launchManagedApplication("terminal")
      else
        hl.exec_cmd(terminal.path, { workspace = "special:terminal silent" })
      end
    end
    hl.exec_cmd("flatpak run com.spotify.Client", { workspace = "special:music silent" })
    hl.exec_cmd("flatpak run com.beeper.Beeper", { workspace = "special:beeper silent" })
    -- Let the existing kJules window rules route the initial window into
    -- special:kjules rather than using a workspace exec rule. This avoids
    -- changing Meta+J into a launcher before kJules is reliably single-instance.
    hl.exec_cmd("kjules")
  end)
end

M.workspace_for_window = workspaceForWindow

return M
