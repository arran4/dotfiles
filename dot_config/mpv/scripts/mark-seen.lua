local utils = require 'mp.utils'

local THRESHOLD = 90
local MARK_ATTR = "user.seen"
local MARK_VALUE = "1"

local marked = false

local function get_os()
  if package.config:sub(1,1) == '\\' then
    return 'windows'
  end
  local f = io.popen('uname -s 2>/dev/null')
  if f then
    local s = f:read('*a')
    f:close()
    if s:match('Darwin') then
      return 'macos'
    end
  end
  return 'linux'
end

local os_name = get_os()

local function mark_seen_xattr(path)
  local args = {}
  if os_name == 'windows' then
    args = {'powershell', '-NoProfile', '-Command', string.format('Set-Content -LiteralPath "%s" -Stream "%s" -Value "%s"', path, MARK_ATTR, MARK_VALUE)}
  elseif os_name == 'macos' then
    args = {'xattr', '-w', MARK_ATTR, MARK_VALUE, path}
  else
    args = {'setfattr', '-n', MARK_ATTR, '-v', MARK_VALUE, path}
  end

  local res = mp.command_native({
    name = "subprocess",
    playback_only = false,
    capture_stdout = true,
    capture_stderr = true,
    args = args
  })

  return res.status == 0
end

local function mark_seen_fallback(path)
  local config_dir = mp.command_native({"expand-path", "~~/"})
  local fallback_file = utils.join_path(config_dir, "seen.txt")
  local f = io.open(fallback_file, "a+")
  if f then
    f:write(path .. "\n")
    f:close()
    mp.msg.info("Fallback: Added to " .. fallback_file)
  else
    mp.msg.error("Failed to write to fallback file: " .. fallback_file)
  end
end

local function mark_seen()
  if marked then return end

  local path = mp.get_property("path")
  if not path then return end

  -- Only operate on local files
  -- Note: On Windows paths might start with drive letter (e.g. C:\)
  -- If it's a relative path, resolve it to an absolute path.
  -- But we must not resolve protocols like http:// or ftp://
  if path:match("^%a+://") then return end

  if not path:match("^/") and not path:match("^%a+:") then
    local workdir = mp.get_property("working-directory")
    if workdir then
      path = utils.join_path(workdir, path)
    else
      return
    end
  end

  mp.msg.info("Attempting to mark as seen: " .. path)

  local success = mark_seen_xattr(path)
  if success then
    mp.msg.info("Marked as seen using extended attributes.")
  else
    mp.msg.warn("Failed to set extended attribute, using fallback.")
    mark_seen_fallback(path)
  end

  marked = true
end

mp.observe_property("percent-pos", "number", function(_, percent)
  if not percent then return end
  if percent >= THRESHOLD then
    mark_seen()
  end
end)

mp.register_event("file-loaded", function()
  marked = false
end)
