local renderedCataloguePath = assert(arg[1], "rendered catalogue path is required")
local renderedWithoutQterminalPath = assert(arg[2], "qterminal-absent render path is required")

local function readFile(path)
  local file = assert(io.open(path, "r"))
  local content = file:read("*a")
  file:close()
  return content
end

local function loadTerminalLogic(path, executablePaths)
  local content = readFile(path)
  local logic = assert(content:match(
    "(local terminalCatalogue = {.-}\n\nlocal function isExecutable.-)local terminal = resolveTerminal%(%)"
  ), "could not extract rendered terminal catalogue")
  local environment = {
    io = {
      open = function(path)
        if executablePaths[path] then
          return { close = function() end }
        end
        return nil
      end,
    },
    ipairs = ipairs,
    os = {
      getenv = function(name)
        if name == "PATH" then
          return "/test/bin"
        end
        return ""
      end,
    },
  }
  return assert(load(
    logic .. " return terminalCatalogue, resolveTerminal()",
    "terminal catalogue",
    "t",
    environment
  ))()
end

local expectedOrder = {
  "foot",
  "qterminal",
  "xterm",
  "rxvt-unicode",
  "urxvt",
  "konsole",
  "ghostty",
  "kitty",
  "alacritty",
  "wezterm",
  "terminator",
  "xfce4-terminal",
  "gnome-terminal",
  "mate-terminal",
  "lxterminal",
}

local allExecutablePaths = {}
for _, name in ipairs(expectedOrder) do
  allExecutablePaths["/test/bin/" .. name] = true
end

local catalogue, terminal = loadTerminalLogic(renderedCataloguePath, allExecutablePaths)
assert(#catalogue == #expectedOrder, "rendered catalogue has an unexpected number of terminals")
for index, expectedName in ipairs(expectedOrder) do
  assert(catalogue[index].name == expectedName, string.format(
    "catalogue entry %d: expected %s, got %s",
    index,
    expectedName,
    tostring(catalogue[index].name)
  ))
end
assert(terminal.name == "foot", "foot must win when discovered and available")

_, terminal = loadTerminalLogic(renderedCataloguePath, {
  ["/test/bin/qterminal"] = true,
})
assert(terminal.name == "qterminal", "qterminal must win when foot is unavailable")

_, terminal = loadTerminalLogic(renderedCataloguePath, {
  ["/test/bin/xterm"] = true,
})
assert(terminal.name == "xterm", "xterm must win when foot and qterminal are unavailable")

_, terminal = loadTerminalLogic(renderedCataloguePath, {
  ["/test/bin/konsole"] = true,
})
assert(terminal.name == "konsole", "konsole must win after foot, qterminal, xterm, rxvt-unicode, and urxvt")

_, terminal = loadTerminalLogic(renderedCataloguePath, {})
assert(terminal.path == "", "no available terminal must produce an empty path")
assert(type(terminal.classes) == "table" and #terminal.classes == 0,
  "no available terminal must produce empty aliases")

local catalogueWithoutPersistedLocations, runtimeFoot = loadTerminalLogic(renderedWithoutQterminalPath, {
  ["/test/bin/foot"] = true,
  ["/test/bin/xterm"] = true,
})
assert(catalogueWithoutPersistedLocations[1].name == "foot",
  "foot must remain the first candidate when footLocation was not persisted")
assert(catalogueWithoutPersistedLocations[2].name == "qterminal",
  "qterminal must remain the second candidate when qterminalLocation was not persisted")
assert(runtimeFoot.name == "foot" and runtimeFoot.path == "/test/bin/foot",
  "foot must resolve from PATH when chezmoi footLocation data is empty or stale")

_, terminal = loadTerminalLogic(renderedWithoutQterminalPath, {
  ["/test/bin/qterminal"] = true,
  ["/test/bin/xterm"] = true,
})
assert(terminal.name == "qterminal" and terminal.path == "/test/bin/qterminal",
  "qterminal must resolve from PATH when chezmoi qterminalLocation data is empty or stale")

_, terminal = loadTerminalLogic(renderedWithoutQterminalPath, {
  ["/test/bin/xterm"] = true,
})
assert(terminal.name == "xterm",
  "runtime foot and qterminal fallbacks must still fall through when neither is installed")

local footConfig = readFile("dot_config/foot/foot.ini.tmpl")
assert(footConfig:find("\n[colors]\n", 1, true), "Foot config must use the compatible [colors] section")
assert(not footConfig:find("\n[colors-dark]\n", 1, true), "Foot config must not use unsupported [colors-dark]")
local configuredFont = assert(
  footConfig:match("\nfont=([^\r\n]+)"),
  "Foot config must define a font"
)
assert(configuredFont == "Hack:size=11", "Foot should use the same Hack family as XTerm")

local hyprlandTemplate = readFile("dot_config/hypr/hyprland.lua.tmpl")
assert(hyprlandTemplate:find(
  'hl.bind("SUPER + N", hl.dsp.global("caelestia:sidebar"))', 1, true
), "Meta+N must open the Caelestia notification sidebar")
assert(hyprlandTemplate:find(
  'hl.bind("SUPER + SHIFT + N", hl.dsp.global("caelestia:clearNotifs"), { locked = true })', 1, true
), "Meta+Shift+N must clear Caelestia notifications")
assert(not hyprlandTemplate:find(
  'hl.bind("SUPER + SHIFT + C", hl.dsp.global("caelestia:clearNotifs"), { locked = true })', 1, true
), "Meta+Shift+C must not remain assigned to clear notifications")
local _, sessionBindingCount = hyprlandTemplate:gsub("caelestia:session", "")
assert(sessionBindingCount == 1, "Caelestia session menu must have only one binding")
assert(hyprlandTemplate:find(
  'hl.bind("SUPER + SHIFT + M", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true })', 1, true
), "Meta+Shift+M must toggle output mute")
assert(hyprlandTemplate:find(
  'local emojiPicker = findInPath("plasma-emojier")', 1, true
), "emoji picker must be discovered from PATH without adding a hard dependency")
assert(hyprlandTemplate:find(
  'hl.bind("SUPER + Period", hl.dsp.exec_cmd(emojiPicker))', 1, true
), "Meta+Period must launch plasma-emojier when available")

local function newScenario(options)
  options = options or {}
  local state = {
    activeSpecial = options.activeSpecial or "",
    binds = {},
    dispatches = {},
    execs = {},
    handlers = {},
    rules = {},
    timers = {},
    workspaceWindows = options.workspaceWindows or {},
    windows = options.windows or {},
  }

  _G.hl = {
    bind = function(keys, action) state.binds[keys] = action end,
    config = function() end,
    dispatch = function(action) table.insert(state.dispatches, action) end,
    exec_cmd = function(...) table.insert(state.execs, { ... }) end,
    on = function(event, callback) state.handlers[event] = callback end,
    timer = function(callback, timerOptions)
      table.insert(state.timers, { callback = callback, options = timerOptions })
    end,
    window_rule = function(rule) table.insert(state.rules, rule) end,
    workspace_rule = function() end,
    dsp = {
      window = {
        move = function(arguments)
          return { kind = "move", arguments = arguments }
        end,
      },
      workspace = {
        toggle_special = function(name)
          return { kind = "toggle", name = name }
        end,
      },
    },
  }

  if options.modern ~= false then
    _G.hl.get_active_special_workspace = function()
      return { name = state.activeSpecial }
    end
    _G.hl.get_workspace_windows = function(workspace)
      if workspace == "special:terminal" then
        return state.workspaceWindows
      end
      return {}
    end
    _G.hl.get_windows = function() return state.windows end
  end

  local special = dofile("dot_config/hypr/special_workspaces.lua")
  special.setup({ terminal = options.terminal })
  return state, special
end

local konsole = {
  path = "/usr/bin/konsole",
  classes = { "konsole", "org.kde.konsole" },
}

local foot = {
  path = "/usr/bin/foot",
  classes = { "foot", "footclient" },
}

do
  local state = newScenario({ terminal = foot })
  local floatingRule
  local modalRule
  for _, rule in ipairs(state.rules) do
    if rule.match and rule.match.float == true then
      floatingRule = rule
    end
    if rule.match and rule.match.modal == true then
      modalRule = rule
    end
  end
  assert(floatingRule and floatingRule.group == "barred",
    "floating windows must be barred from automatic groups")
  assert(modalRule and modalRule.float == true and modalRule.group == "barred",
    "modal windows must float and be barred from automatic groups")
end

do
  local _, special = newScenario({ terminal = konsole })
  assert(special.workspace_for_window({ class = "konsole" }) == "terminal")
  assert(special.workspace_for_window({ class = "org.kde.konsole" }) == "terminal")
  assert(special.workspace_for_window({ class = "xterm" }) == nil)
  assert(special.workspace_for_window({ class = "foot" }) == nil)
  assert(special.workspace_for_window({ class = "qterminal" }) == nil)
  assert(special.workspace_for_window({ class = "kmagmux" }) == "kmagmux")
  assert(special.workspace_for_window({ class = "org.kde.kmagmux" }) == "kmagmux")
  assert(special.workspace_for_window({ class = "which_browser" }) == "which_browser")
  assert(special.workspace_for_window({ class = "com.arran4.whichbrowser.which_browser" }) == "which_browser")
end

do
  local state = newScenario({ terminal = konsole })
  assert(type(state.binds["SUPER + K"]) == "function")
  state.binds["SUPER + K"]()
  assert(#state.execs == 1)
  assert(state.execs[1][1] == "kmagmux --show")
  assert(state.execs[1][2].workspace == "special:kmagmux silent")
  state.handlers["window.open"]({ class = "kmagmux" })
  assert(#state.dispatches == 2, "toggle and pending routing were expected for kmagmux")
  assert(state.dispatches[2].kind == "move")
  assert(state.dispatches[2].arguments.workspace == "special:kmagmux")
  assert(state.dispatches[2].arguments.follow == false)

  -- Test hiding it when active
  local state2 = newScenario({ terminal = konsole, activeSpecial = "special:kmagmux" })
  state2.binds["SUPER + K"]()
  assert(#state2.dispatches == 1 and state2.dispatches[1].kind == "toggle")
  assert(#state2.execs == 0)

  -- Test claiming it when already mapped on another workspace
  local state3 = newScenario({ terminal = konsole, windows = { { class = "kmagmux", workspace = { name = "1" } } } })
  state3.binds["SUPER + K"]()
  assert(#state3.dispatches == 3) -- one for setup routeWindow, one for move, one for toggle
  assert(#state3.execs == 0, "kmagmux should not be executed if an existing window is claimed")
end

do
  local state = newScenario({ terminal = konsole })
  assert(type(state.binds["SUPER + SHIFT + underscore"]) == "function")
  state.binds["SUPER + SHIFT + underscore"]()
  assert(#state.execs == 1)
  assert(state.execs[1][1] == "which_browser")
  assert(state.execs[1][2].workspace == "special:which_browser silent")
  state.handlers["window.open"]({ class = "which_browser" })
  assert(#state.dispatches == 2, "toggle and pending routing were expected for which_browser")
  assert(state.dispatches[2].kind == "move")
  assert(state.dispatches[2].arguments.workspace == "special:which_browser")
  assert(state.dispatches[2].arguments.follow == false)

  -- Test hiding it when active
  local state2 = newScenario({ terminal = konsole, activeSpecial = "special:which_browser" })
  state2.binds["SUPER + SHIFT + underscore"]()
  assert(#state2.dispatches == 1 and state2.dispatches[1].kind == "toggle")
  assert(#state2.execs == 0)

  -- Test claiming it when already mapped on another workspace
  local state3 = newScenario({ terminal = konsole, windows = { { class = "which_browser", workspace = { name = "1" } } } })
  state3.binds["SUPER + SHIFT + underscore"]()
  assert(#state3.dispatches == 3) -- one for setup routeWindow, one for move, one for toggle
  assert(#state3.execs == 0, "which_browser should not be executed if an existing window is claimed")
end

do
  local _, special = newScenario({ terminal = foot })
  assert(special.workspace_for_window({ class = "foot" }) == "terminal")
  assert(special.workspace_for_window({ class = "footclient" }) == "terminal")
  assert(special.workspace_for_window({ class = "qterminal" }) == nil)
end

do
  local state = newScenario({ terminal = konsole })
  state.handlers["window.open"]({ class = "org.kde.konsole" })
  state.handlers["window.open"]({ class = "xterm" })
  assert(#state.dispatches == 0, "normal terminal windows must not be routed")
end

do
  local state = newScenario({ terminal = konsole })
  assert(type(state.binds["SUPER + grave"]) == "function")
  state.binds["SUPER + grave"]()
  assert(#state.execs == 1)
  assert(state.execs[1][1] == konsole.path)
  assert(state.execs[1][2].workspace == "special:terminal silent")
  state.handlers["window.open"]({ class = "org.kde.konsole" })
  assert(#state.dispatches == 2, "toggle and pending-terminal routing were expected")
  assert(state.dispatches[2].kind == "move")
  assert(state.dispatches[2].arguments.workspace == "special:terminal")
  assert(state.dispatches[2].arguments.follow == false)
end

do
  local state = newScenario({
    terminal = konsole,
    workspaceWindows = { { class = "org.kde.konsole" } },
  })
  state.binds["SUPER + grave"]()
  assert(#state.execs == 0, "an existing special terminal must not be relaunched")
  assert(#state.dispatches == 1 and state.dispatches[1].kind == "toggle")
end

do
  for _, residentClass in ipairs({ "rxvt", "qterminal", "org.kde.konsole" }) do
    local state = newScenario({
      terminal = foot,
      workspaceWindows = { { class = residentClass } },
    })
    state.binds["SUPER + grave"]()
    assert(#state.execs == 0, string.format(
      "%s in special:terminal must satisfy the terminal invariant when foot is preferred",
      residentClass
    ))
    assert(#state.dispatches == 1 and state.dispatches[1].kind == "toggle")
  end
end

do
  local state = newScenario({
    terminal = foot,
    workspaceWindows = { { class = "firefox" } },
  })
  state.binds["SUPER + grave"]()
  assert(#state.execs == 1 and state.execs[1][1] == foot.path,
    "an unrelated special-workspace window must not satisfy the terminal invariant")
end

do
  local state = newScenario({
    terminal = foot,
    workspaceWindows = { { class = "rxvt" } },
  })
  assert(type(state.handlers["window.close"]) == "function")
  state.handlers["window.close"]({
    class = "rxvt",
    workspace = { name = "special:terminal" },
  })
  assert(#state.execs == 0, "replacement launch must wait for the workspace list to update")
  assert(#state.timers == 1 and state.timers[1].options.timeout == 1)
  state.workspaceWindows = {}
  state.timers[1].callback()
  assert(#state.execs == 1 and state.execs[1][1] == foot.path,
    "closing the last supported terminal must launch the preferred terminal")
  assert(state.execs[1][2].workspace == "special:terminal silent")
end

do
  local state = newScenario({
    terminal = foot,
    workspaceWindows = { { class = "foot" }, { class = "rxvt" } },
  })
  state.handlers["window.close"]({
    class = "foot",
    workspace = { name = "special:terminal" },
  })
  state.workspaceWindows = { { class = "rxvt" } }
  state.timers[1].callback()
  assert(#state.execs == 0,
    "closing the preferred terminal must not relaunch it while another supported terminal remains")
end

do
  local state = newScenario({ terminal = foot })
  state.handlers["window.close"]({
    class = "rxvt",
    workspace = { name = "1" },
  })
  assert(#state.timers == 0 and #state.execs == 0,
    "closing a supported terminal outside special:terminal must not populate the special workspace")
end

do
  local state = newScenario({ terminal = konsole })
  assert(type(state.binds["SUPER + T"]) == "function")
  state.binds["SUPER + T"]()
  assert(#state.execs == 1 and state.execs[1][1] == konsole.path)
  assert(state.execs[1][2] == nil, "normal terminal launch must not have workspace arguments")
  assert(state.binds["SUPER + SHIFT + T"] == nil, "redundant Meta+Shift+T binding must not be registered")
  state.handlers["window.open"]({ class = "konsole" })
  assert(#state.dispatches == 0, "normal terminal window must remain outside special:terminal")
end

do
  local specialClass = [=[literal\pipe|braces{}dot.plus+star*question?paren()brackets[]anchors^$]=]
  local state = newScenario({
    modern = false,
    terminal = {
      path = "/usr/bin/konsole",
      classes = { "konsole", "org.kde.konsole", specialClass },
    },
  })
  local terminalRule
  for _, rule in ipairs(state.rules) do
    if rule.workspace == "special:terminal" then
      terminalRule = rule
    end
  end
  assert(terminalRule, "legacy terminal rule was not generated")
  local expected = [=[^(konsole|org\.kde\.konsole|literal\\pipe\|braces\{\}dot\.plus\+star\*question\?paren\(\)brackets\[\]anchors\^\$)$]=]
  assert(terminalRule.match.class == expected, string.format(
    "legacy regex mismatch\nexpected: %s\nactual:   %s",
    expected,
    terminalRule.match.class
  ))
  assert(not terminalRule.match.class:find("xterm", 1, true))
  assert(not terminalRule.match.class:find("foot", 1, true))
  assert(not terminalRule.match.class:find("qterminal", 1, true))
end

do
  local state = newScenario({
    modern = false,
    terminal = foot,
  })
  local terminalRule
  for _, rule in ipairs(state.rules) do
    if rule.workspace == "special:terminal" then
      terminalRule = rule
    end
  end
  assert(terminalRule and terminalRule.match.class == "^(foot|footclient)$")
  assert(state.handlers["window.close"] == nil,
    "legacy runtimes without workspace state must not register invariant maintenance")
end

print("Hyprland terminal catalogue and special-workspace regression tests passed")
