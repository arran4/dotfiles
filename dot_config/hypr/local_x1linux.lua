-- Monitor configuration for x1linux
hl.monitor({
  output = "eDP-1",
  mode = "preferred",
  position = "0x0",
  scale = 1.5,
})
hl.monitor({
  output = "",
  mode = "preferred",
  position = "auto",
  scale = 1.5,
})

require("special_workspaces")
