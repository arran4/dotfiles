local utils = require 'mp.utils'

local THRESHOLD = 90
local MARK_ATTR = "user.seen"
local MARK_VALUE = "1"

local marked = false
local last_comment_percent = 0

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

local function get_xattr(path, attr)
  local res = mp.command_native({
    name = "subprocess",
    playback_only = false,
    capture_stdout = true,
    args = {"getfattr", "--only-values", "-n", attr, path}
  })
  if res.status == 0 and res.stdout then
    return res.stdout:gsub("\n$", "")
  end
  return nil
end

local function set_xattr(path, attr, value)
  local res = mp.command_native({
    name = "subprocess",
    playback_only = false,
    capture_stdout = true,
    capture_stderr = true,
    args = {'setfattr', '-n', attr, '-v', value, path}
  })
  return res.status == 0
end

local function mark_seen_xattr(path, percent, time_pos)
  if os_name == 'windows' then
    local args = {'powershell', '-NoProfile', '-Command', string.format('Set-Content -LiteralPath "%s" -Stream "%s" -Value "%s"', path, MARK_ATTR, MARK_VALUE)}
    local res = mp.command_native({
      name = "subprocess",
      playback_only = false,
      capture_stdout = true,
      capture_stderr = true,
      args = args
    })
    return res.status == 0
  elseif os_name == 'macos' then
    local args = {'xattr', '-w', MARK_ATTR, MARK_VALUE, path}
    local res = mp.command_native({
      name = "subprocess",
      playback_only = false,
      capture_stdout = true,
      capture_stderr = true,
      args = args
    })
    return res.status == 0
  else
    local success = true

    -- 1. user.xdg.tags
    local tags = get_xattr(path, "user.xdg.tags")
    local new_tags = tags
    if tags then
      -- Support upper case conversions to lower case
      new_tags = string.gsub(tags, "Seen", "seen")
    end

    if not new_tags or new_tags == "" then
      new_tags = "seen"
    elseif not string.find("," .. new_tags .. ",", ",seen,") then
      new_tags = new_tags .. ",seen"
    end
    if new_tags ~= tags then
      if not set_xattr(path, "user.xdg.tags", new_tags) then success = false end
    end

    -- 2. user.watched
    if not set_xattr(path, "user.watched", tostring(time_pos or 0)) then success = false end

    return success
  end
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

local function update_comment(path, percent, time_pos)
  if os_name == 'windows' or os_name == 'macos' then
    return true
  end

  local comment = get_xattr(path, "user.xdg.comment")

  local s = math.floor(time_pos or 0)
  local h = math.floor(s / 3600)
  s = s % 3600
  local m = math.floor(s / 60)
  s = s % 60
  local time_str = ""
  if h > 0 then
    time_str = string.format("%d:%02d:%02d", h, m, s)
  else
    time_str = string.format("%d:%02d", m, s)
  end

  local append_str = string.format("Watched %d%% at %s", math.floor(percent or 0), time_str)
  local new_comment = comment
  if not comment or comment == "" then
    new_comment = append_str
  else
    new_comment = comment .. "\n" .. append_str
  end
  return set_xattr(path, "user.xdg.comment", new_comment)
end

local function get_valid_path()
  local path = mp.get_property("path")
  if not path then return nil end

  -- Only operate on local files
  -- Note: On Windows paths might start with drive letter (e.g. C:\)
  -- If it's a relative path, resolve it to an absolute path.
  -- But we must not resolve protocols like http:// or ftp://
  if path:match("^%a+://") then return nil end

  if not path:match("^/") and not path:match("^%a+:") then
    local workdir = mp.get_property("working-directory")
    if workdir then
      path = utils.join_path(workdir, path)
    else
      return nil
    end
  end
  return path
end

local function mark_comment(percent, time_pos)
  local path = get_valid_path()
  if not path then return end

  update_comment(path, percent, time_pos)
end

local function mark_seen(percent, time_pos)
  if marked then return end

  local path = get_valid_path()
  if not path then return end

  mp.msg.info("Attempting to mark as seen: " .. path)

  local success = mark_seen_xattr(path, percent, time_pos)
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

  local time_pos = mp.get_property_number("time-pos")

  if percent >= last_comment_percent + 5 then
    mark_comment(percent, time_pos)
    last_comment_percent = math.floor(percent)
  end

  if percent >= THRESHOLD then
    mark_seen(percent, time_pos)
  end
end)

mp.register_event("file-loaded", function()
  marked = false
  last_comment_percent = 0
end)
