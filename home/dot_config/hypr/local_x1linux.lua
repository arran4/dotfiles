-- Monitor configuration for x1linux
-- Work around the Hyprland 0.57/NVIDIA display regression by disabling HDR
-- capability reporting for both the built-in panel and fallback monitors.
hl.monitor({
  output = "eDP-1",
  mode = "preferred",
  position = "0x0",
  scale = 1.67,
  supports_hdr = -1,
})
hl.monitor({
  output = "",
  mode = "preferred",
  position = "auto",
  scale = 1.67,
  supports_hdr = -1,
})
