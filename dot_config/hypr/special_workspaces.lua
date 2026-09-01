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
  { name = "which_browser", key = "SUPER + SHIFT + underscore" },
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
  terminal = {}, -- Populated dynamically in setup with the preferred terminal only.
  kjules = {
    ["kjules"] = true,
    ["org.kde.kjules"] = true,
    ["io.github.arran4.kjules"] = true,
  },
  which_browser = {
    ["which_browser"] = true,
    ["com.arran4.whichbrowser.which_browser"] = true,
  },
}

-- Any supported terminal already resident in special:terminal satisfies the
-- workspace invariant. Keep this catalogue-wide set separate from
-- classRoutes.terminal: the latter deliberately contains only the preferred
-- terminal so ordinary launches of another supported terminal are never
-- captured just because a special-terminal launch is pending.
--
-- Keep these aliases in sync with terminalCatalogue in hyprland.lua.tmpl.
local supportedTerminalClasses = {
  ["foot"] = true,
  ["footclient"] = true,
  ["qterminal"] = true,
  ["xterm"] = true,
  ["rxvt-unicode"] = true,
  ["rxvt"] = true,
  ["urxvt"] = true,
  ["konsole"] = true,
  ["org.kde.konsole"] = true,
  ["ghostty"] = true,
  ["com.mitchellh.ghostty"] = true,
  ["kitty"] = true,
  ["kitty-direct"] = true,
  ["alacritty"] = true,
  ["wezterm"] = true,
  ["org.wezfurlong.wezterm"] = true,
  ["terminator"] = true,
  ["xfce4-terminal"] = true,
  ["gnome-terminal"] = true,
  ["gnome-terminal-server"] = true,
  ["org.gnome.terminal"] = true,
  ["org.gnome.console"] = true,
  ["mate-terminal"] = true,
  ["lxterminal"] = true,
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

  -- Groups are explicit tabbed containers. Do not silently pull newly-created
  -- windows into the focused group; Super+G enters a one-shot management mode
  -- for deliberate grouping and tab operations instead.
  if type(hl.config) == "function" then
    hl.config({
      group = {
        auto_group = false,
        groupbar = {
          enabled = true,
          render_titles = true,
        },
      },
    })

    -- Respect client/compositor floating intent. auto_group would otherwise
    -- pull popup and transient windows (including browser extension/password-
    -- manager windows) into the focused group and tile them. Modal dialogs
    -- should also remain floating when their client only supplies the modal hint.
    hl.window_rule({
      match = { float = true },
      group = "barred",
    })
    hl.window_rule({
      match = { modal = true },
      float = true,
      group = "barred",
    })
  end

  -- Group dispatchers are optional in older/mock Hyprland Lua runtimes. Resolve
  -- them dynamically so loading the rest of this module remains safe and so the
  -- repository's dispatcher validator does not need to model grouped dispatchers.
  local groupDispatcher = type(hl.dsp) == "table" and hl.dsp["group"] or nil
  local submapDispatcher = type(hl.dsp) == "table" and hl.dsp["submap"] or nil
  local windowDispatcher = type(hl.dsp) == "table" and hl.dsp["window"] or nil

  -- Keep fast tab switching available outside group-management mode. These were
  -- the established bindings before grouping became explicit and are useful
  -- often enough not to require entering the one-shot submap first.
  if type(groupDispatcher) == "table"
    and type(groupDispatcher.next) == "function"
    and type(groupDispatcher.prev) == "function" then
    hl.bind("SUPER + CTRL + Up", groupDispatcher.prev(), { repeating = true, desc = "Previous window in group" })
    hl.bind("SUPER + CTRL + Down", groupDispatcher.next(), { repeating = true, desc = "Next window in group" })
  end

  if type(groupDispatcher) == "table"
    and type(groupDispatcher.next) == "function"
    and type(groupDispatcher.prev) == "function"
    and type(groupDispatcher.move_window) == "function"
    and type(groupDispatcher.toggle) == "function"
    and type(submapDispatcher) == "function"
    and type(windowDispatcher) == "table"
    and type(windowDispatcher.move) == "function"
    and type(hl.define_submap) == "function"
    and type(hl.dispatch) == "function" then
    hl.bind("SUPER + G", submapDispatcher("group_management"), {
      desc = "Enter group management mode",
    })

    local function mapGroupAction(key, action, desc)
      hl.bind(key, function()
        hl.dispatch(action)
        hl.dispatch(submapDispatcher("reset"))
      end, { desc = desc })
    end

    hl.define_submap("group_management", function()
      for _, binding in ipairs({
        { key = "h", direction = "l", name = "left" },
        { key = "Left", direction = "l", name = "left" },
        { key = "j", direction = "d", name = "down" },
        { key = "Down", direction = "d", name = "down" },
        { key = "k", direction = "u", name = "up" },
        { key = "Up", direction = "u", name = "up" },
        { key = "l", direction = "r", name = "right" },
        { key = "Right", direction = "r", name = "right" },
      }) do
        mapGroupAction(
          binding.key,
          windowDispatcher.move({ into_or_create_group = binding.direction }),
          "Group with the " .. binding.name .. " neighbour"
        )
      end

      mapGroupAction("e", windowDispatcher.move({ out_of_group = true }), "Extract window from group")
      mapGroupAction("n", groupDispatcher.next(), "Next window in group")
      mapGroupAction("p", groupDispatcher.prev(), "Previous window in group")
      mapGroupAction("f", groupDispatcher.move_window(), "Move window forward in group")
      mapGroupAction("b", groupDispatcher.move_window({ forward = false }), "Move window backward in group")
      mapGroupAction("t", groupDispatcher.toggle(), "Toggle window group")
      hl.bind("Escape", submapDispatcher("reset"), { desc = "Cancel group management mode" })
    end)
  end

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
    -- special terminal. Ordinary terminal launches (for example Meta+T) must
    -- remain on the normal workspace instead of being captured by class.
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
      if supportedTerminalClasses[lower(window.class)] then
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
      return
    end

    if name == "kjules" then
      -- kJules is single-instance via KDBusService::Unique. Re-running it
      -- activates the existing instance, while a missing instance starts here.
      hl.exec_cmd("kjules", { workspace = "special:kjules silent" })
      return
    end

    if name == "which_browser" then
      -- Use Which Browser's explicit single-instance activation contract so a
      -- tray-only process reliably maps and focuses its main window.
      hl.exec_cmd("which_browser --show", { workspace = "special:which_browser silent" })
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
    -- also covers single-instance processes that are currently tray-only.
    local hasWindow = routeExistingApplication(name)
    hl.dispatch(hl.dsp.workspace.toggle_special(name))
    if not hasWindow then
      launchManagedApplication(name)
    end
  end

  for _, workspace in ipairs(workspaces) do
    local action = hl.dsp.workspace.toggle_special(workspace.name)
    if smartManagedWorkspaces
      and (workspace.name == "music" or workspace.name == "beeper" or workspace.name == "terminal"
        or workspace.name == "kjules" or workspace.name == "which_browser") then
      action = function()
        toggleManagedWorkspace(workspace.name)
      end
    end

    hl.bind(workspace.key, action)
    hl.workspace_rule({ workspace = "special:" .. workspace.name, persistent = true })
  end

  -- On modern Hyprland, Meta+T explicitly launches a new normal terminal
  -- outside special:terminal. Keep the historical direct-toggle fallback on
  -- runtimes too old to expose the workspace state needed for managed routing.
  if smartManagedWorkspaces then
    if terminal.path ~= "" then
      hl.bind("SUPER + T", function()
        hl.exec_cmd(terminal.path)
      end)
    end
  else
    hl.bind("SUPER + T", hl.dsp.workspace.toggle_special("terminal"))
  end

  -- kJules registers Meta+Shift+J with KGlobalAccel on KDE. Hyprland owns
  -- global shortcuts itself, so invoke the compositor-friendly CLI equivalent.
  -- KDBusService forwards this to an existing kJules instance or starts one.
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
    match = { class = "^(kJules|kjules|org.kde.kjules|io.github.arran4.kjules)$" },
    workspace = "special:kjules",
  })
  hl.window_rule({
    match = { class = "^(which_browser|com\\.arran4\\.whichbrowser\\.which_browser)$" },
    workspace = "special:which_browser",
  })

  -- Fully initialized windows are the normal path. Listen for class changes
  -- too because Electron/Wayland clients may publish their final app id after
  -- mapping.
  hl.on("window.open", routeWindow)
  hl.on("window.class", routeWindow)

  -- Maintain the terminal workspace invariant after its last supported
  -- terminal closes. window.close can fire before the compositor's workspace
  -- list is fully updated, so defer the occupancy check when timers are
  -- available. Closing a supported terminal on a normal workspace must never
  -- populate special:terminal.
  if smartManagedWorkspaces then
    hl.on("window.close", function(window)
      if not supportedTerminalClasses[lower(window and window.class)] then
        return
      end
      if specialName(window and window.workspace) ~= "terminal" then
        return
      end

      local function ensureTerminalResident()
        if not hasSpecialTerminal() then
          launchManagedApplication("terminal")
        end
      end

      if type(hl.timer) == "function" then
        hl.timer(ensureTerminalResident, { timeout = 1, type = "oneshot" })
      else
        ensureTerminalResident()
      end
    end)
  end

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
  -- special-workspace residents. kJules is now safe to activate repeatedly:
  -- KDBusService forwards a second launch to the existing instance.
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
    if smartManagedWorkspaces then
      launchManagedApplication("kjules")
    else
      hl.exec_cmd("kjules")
    end
  end)
end

M.workspace_for_window = workspaceForWindow

return M