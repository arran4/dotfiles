-- Monitor configuration for x1linux
hl.monitor({
  output = "eDP-1",
  mode = "preferred",
  position = "0x0",
  scale = 1.67,
})
hl.monitor({
  output = "",
  mode = "preferred",
  position = "auto",
  scale = 1.67,
})

-- This module is selected by hostname x1linux in hyprland.lua.
-- Limit the click/gesture diagnosis to the internal Synaptics touchpad;
-- the TrackPoint and externally connected pointers retain their own settings.
hl.device({
  name = "synaptics-tm3512-010",
  -- Rule out unintended taps and tap-and-drag recognition as causes of
  -- duplicate clicks and post-click movement delays. Physical click and
  -- two-finger scrolling remain enabled by their normal defaults.
  tap_to_click = false,
  tap_and_drag = false,
  drag_lock = 0,
})
