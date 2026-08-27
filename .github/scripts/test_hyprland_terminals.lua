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
    os = { getenv = function() return "" end },
  }
  return assert(load(
    logic .. " return terminalCatalogue, resolveTerminal()",
    "terminal catalogue",
    "t",
    environment
  ))()
end

local expectedOrder = {
  "qterminal",
  "xterm",
  "rxvt-unicode",
  "urxvt",
  "konsole",
  "ghostty",
  "foot",
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
assert(terminal.name == "qterminal", "qterminal must win when discovered and available")

_, terminal = loadTerminalLogic(renderedCataloguePath, {
  ["/test/bin/xterm"] = true,
})
assert(terminal.name == "xterm", "xterm must win when qterminal is unavailable")

_, terminal = loadTerminalLogic(renderedCataloguePath, {
  ["/test/bin/konsole"] = true,
})
assert(terminal.name == "konsole", "konsole must win after qterminal, xterm, rxvt-unicode, and urxvt")

_, terminal = loadTerminalLogic(renderedCataloguePath, {})
assert(terminal.path == "", "no available terminal must produce an empty path")
assert(type(terminal.classes) == "table" and #terminal.classes == 0,
  "no available terminal must produce empty aliases")

local catalogueWithoutQterminal = loadTerminalLogic(renderedWithoutQterminalPath, allExecutablePaths)
for _, candidate in ipairs(catalogueWithoutQterminal) do
  assert(candidate.name ~= "qterminal", "undiscovered qterminal must not be a candidate")
end
assert(catalogueWithoutQterminal[1].name == "xterm",
  "xterm must be first when qterminal was not discovered")

local function newScenario(options)
  options = options or {}
  local state = {
    activeSpecial = options.activeSpecial or "",
    binds = {},
    dispatches = {},
    execs = {},
    handlers = {},
    rules = {},
    workspaceWindows = options.workspaceWindows or {},
    windows = options.windows or {},
  }

  _G.hl = {
    bind = function(keys, action) state.binds[keys] = action end,
    dispatch = function(action) table.insert(state.dispatches, action) end,
    exec_cmd = function(...) table.insert(state.execs, { ... }) end,
    on = function(event, callback) state.handlers[event] = callback end,
    timer = function() end,
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

do
  local _, special = newScenario({ terminal = konsole })
  assert(special.workspace_for_window({ class = "konsole" }) == "terminal")
  assert(special.workspace_for_window({ class = "org.kde.konsole" }) == "terminal")
  assert(special.workspace_for_window({ class = "xterm" }) == nil)
  assert(special.workspace_for_window({ class = "foot" }) == nil)
  assert(special.workspace_for_window({ class = "qterminal" }) == nil)
end

do
  local _, special = newScenario({
    terminal = { path = "/usr/bin/qterminal", classes = { "qterminal" } },
  })
  assert(special.workspace_for_window({ class = "qterminal" }) == "terminal")
  assert(special.workspace_for_window({ class = "konsole" }) == nil)
end

do
  local state = newScenario({ terminal = konsole })
  state.handlers["window.open"]({ class = "org.kde.konsole" })
  state.handlers["window.open"]({ class = "xterm" })
  assert(#state.dispatches == 0, "normal terminal windows must not be routed")
end

do
  local state = newScenario({ terminal = konsole })
  assert(type(state.binds["SUPER + T"]) == "function")
  state.binds["SUPER + T"]()
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
  local state = newScenario({ terminal = konsole })
  state.binds["SUPER + SHIFT + T"]()
  assert(#state.execs == 1 and state.execs[1][1] == konsole.path)
  assert(state.execs[1][2] == nil, "normal terminal launch must not have workspace arguments")
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
    terminal = { path = "/usr/bin/qterminal", classes = { "qterminal" } },
  })
  local terminalRule
  for _, rule in ipairs(state.rules) do
    if rule.workspace == "special:terminal" then
      terminalRule = rule
    end
  end
  assert(terminalRule and terminalRule.match.class == "^(qterminal)$")
end

print("Hyprland terminal catalogue and special-workspace regression tests passed")
