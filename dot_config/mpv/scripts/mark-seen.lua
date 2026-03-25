local utils = require 'mp.utils'

local THRESHOLD = 90
local UPDATE_INTERVAL = 10
local MARK_ATTR = "user.seen"
local MARK_VALUE = "1"

local seen_marked = false
local last_update_percent = 0
local fallback_marked = false

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

local function mark_seen_xattr(path, percent, time_pos, is_seen)
  if os_name == 'windows' then
    if is_seen then
      local args = {'powershell', '-NoProfile', '-Command', string.format('Set-Content -LiteralPath "%s" -Stream "%s" -Value "%s"', path, MARK_ATTR, MARK_VALUE)}
      local res = mp.command_native({
        name = "subprocess",
        playback_only = false,
        capture_stdout = true,
        capture_stderr = true,
        args = args
      })
      return res.status == 0
    end
    return true
  elseif os_name == 'macos' then
    if is_seen then
      local args = {'xattr', '-w', MARK_ATTR, MARK_VALUE, path}
      local res = mp.command_native({
        name = "subprocess",
        playback_only = false,
        capture_stdout = true,
        capture_stderr = true,
        args = args
      })
      return res.status == 0
    end
    return true
  else
    local success = true

    -- 1. user.xdg.tags
    if is_seen then
      local tags = get_xattr(path, "user.xdg.tags")
      local new_tags = tags
      if not tags or tags == "" then
        new_tags = "Seen"
      elseif not string.find("," .. tags .. ",", ",Seen,") then
        new_tags = tags .. ",Seen"
      end
      if new_tags ~= tags then
        if not set_xattr(path, "user.xdg.tags", new_tags) then success = false end
      end
    end

    -- 2. user.xdg.comment
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

    local new_lines = {}
    if comment and comment ~= "" then
      for line in comment:gmatch("[^\r\n]+") do
        if not line:match("^Watched %d+%% at [%d:]+$") then
          table.insert(new_lines, line)
        end
      end
    end
    table.insert(new_lines, append_str)

    local new_comment = table.concat(new_lines, "\n")
    if not set_xattr(path, "user.xdg.comment", new_comment) then success = false end

    -- 3. user.watched
    if not set_xattr(path, "user.watched", tostring(time_pos or 0)) then success = false end

    return success
  end
end

local function mark_seen_fallback(path)
  if fallback_marked then return end
  local config_dir = mp.command_native({"expand-path", "~~/"})
  local fallback_file = utils.join_path(config_dir, "seen.txt")
  local f = io.open(fallback_file, "a+")
  if f then
    f:write(path .. "\n")
    f:close()
    mp.msg.info("Fallback: Added to " .. fallback_file)
    fallback_marked = true
  else
    mp.msg.error("Failed to write to fallback file: " .. fallback_file)
  end
end

local function update_progress(percent, time_pos)
  local path = mp.get_property("path")
  if not path then return end

  if path:match("^%a+://") then return end

  if not path:match("^/") and not path:match("^%a+:") then
    local workdir = mp.get_property("working-directory")
    if workdir then
      path = utils.join_path(workdir, path)
    else
      return
    end
  end

  local is_seen = (percent >= THRESHOLD)

  mp.msg.info("Attempting to update progress for: " .. path .. string.format(" (%d%%)", percent))

  local success = mark_seen_xattr(path, percent, time_pos, is_seen)
  if success then
    mp.msg.info("Progress updated using extended attributes.")
  else
    if is_seen then
      mp.msg.warn("Failed to set extended attribute, using fallback.")
      mark_seen_fallback(path)
    end
  end

  if is_seen then
    seen_marked = true
  end
end

mp.observe_property("percent-pos", "number", function(_, percent)
  if not percent then return end

  local do_update = false
  if percent >= last_update_percent + UPDATE_INTERVAL then
    do_update = true
  elseif percent >= THRESHOLD and not seen_marked then
    do_update = true
  end

  if do_update then
    local time_pos = mp.get_property_number("time-pos")
    update_progress(percent, time_pos)
    if percent >= last_update_percent + UPDATE_INTERVAL then
      last_update_percent = math.floor(percent / UPDATE_INTERVAL) * UPDATE_INTERVAL
    end
  end
end)

mp.register_event("file-loaded", function()
  seen_marked = false
  last_update_percent = 0
  fallback_marked = false
end)
