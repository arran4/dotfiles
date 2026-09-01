local M = {}

local initialized = false

function M.setup()
  if initialized or type(hl) ~= "table" or type(hl.exec_cmd) ~= "function" then
    return
  end

  local originalExec = hl.exec_cmd
  hl.exec_cmd = function(command, options)
    if command == "kjules" or command == "kmagmux" then
      local home = os.getenv("HOME") or ""
      local helper = home .. "/.config/hypr/launch-scaled-app"
      command = string.format("%q %s", helper, command)
    end
    return originalExec(command, options)
  end

  initialized = true
end

return M
