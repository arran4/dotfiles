-- Regression coverage for the host-scoped X1 touchpad settings.
-- Run from the repository root: lua5.4 .github/scripts/test_hyprland_x1_touchpad.lua

local function readFile(path)
  local file = assert(io.open(path, "r"))
  local contents = file:read("*a")
  file:close()
  return contents
end

local function loadHostModule(path)
  local monitors, devices = {}, {}
  _G.hl = {
    monitor = function(config)
      table.insert(monitors, config)
    end,
    device = function(config)
      table.insert(devices, config)
    end,
  }
  assert(loadfile(path))()
  return monitors, devices
end

-- The main rendered config selects local_x1linux by hostname, rather than
-- applying the touchpad settings to every installation.
local template = readFile("dot_config/hypr/hyprland.lua.tmpl")
assert(template:find('addCandidate("local_" .. hostname)', 1, true),
  "Hyprland must continue to select hostname-specific modules")
assert(template:find('pcall(require, modName)', 1, true),
  "Hyprland must continue to load only the selected host module")

local x1Monitors, x1Devices = loadHostModule("dot_config/hypr/local_x1linux.lua")
assert(#x1Monitors == 2, "X1 monitor configuration must be preserved")
assert(x1Monitors[1].output == "eDP-1" and x1Monitors[1].scale == 1.67,
  "X1 built-in monitor configuration must remain unchanged")
assert(#x1Devices == 1, "only one device should be configured on x1linux")
local touchpad = x1Devices[1]
assert(touchpad.name == "synaptics-tm3512-010", "must target the observed X1 touchpad")
assert(touchpad.tap_to_click == false, "tap-generated clicks must be disabled")
assert(touchpad.tap_and_drag == false, "tap-and-drag must be disabled")
assert(touchpad.drag_lock == 0, "drag lock must be off")
local expectedKeys = { name = true, tap_to_click = true, tap_and_drag = true, drag_lock = true }
for key in pairs(touchpad) do
  assert(expectedKeys[key], "unexpected touchpad override: " .. tostring(key))
end

-- The other host's module must remain independent of the X1 settings.
local desktopMonitors, desktopDevices = loadHostModule("dot_config/hypr/local_desktop2.lua")
assert(#desktopMonitors == 2 and desktopMonitors[1].output == "HDMI-A-1",
  "desktop2 monitor configuration must be preserved")
assert(#desktopDevices == 0, "X1 touchpad settings must not affect desktop2")

print("Hyprland X1 touchpad host-scoping tests passed")
