local THRESHOLD = 90
local MARK_ATTR = "user.seen"
local MARK_VALUE = "1"

local marked = false

local function mark_seen()
  if marked then return end

  local path = mp.get_property("path")
  if not path then return end

  -- Only operate on local files
  if not path:match("^/") then return end

  -- Escape quotes for shell
  local safe_path = path:gsub('"', '\\"')

  local cmd = string.format(
    'setfattr -n %s -v %s "%s"',
    MARK_ATTR,
    MARK_VALUE,
    safe_path
  )

  mp.msg.info("Marking as seen: " .. path)
  os.execute(cmd)

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
