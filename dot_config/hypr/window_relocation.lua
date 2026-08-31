-- Carry a window across relative workspaces without repeatedly retiling it.
--
-- The first relative move picks up the active window. Tiled windows are floated
-- and reduced enough to leave the destination workspace visible. Subsequent
-- moves keep the same floating geometry. Releasing Super calls finish(), which
-- retiles only windows that started tiled.

local M = {}

local state = {
  window = nil,
  was_floating = false,
}

local function reset()
  state.window = nil
  state.was_floating = false
end

local function windowDispatcher()
  if type(hl) ~= "table" or type(hl.dsp) ~= "table" then
    return nil
  end
  if type(hl.dsp.window) ~= "table" then
    return nil
  end
  return hl.dsp.window
end

local function shrinkForCarry(window, dispatcher)
  if window == nil or window.floating == true then
    return
  end

  local monitor = window.monitor
  if monitor == nil and type(hl.get_active_monitor) == "function" then
    monitor = hl.get_active_monitor()
  end

  local size = window.size
  if monitor == nil or size == nil then
    return
  end
  if type(monitor.width) ~= "number" or type(monitor.height) ~= "number" then
    return
  end
  if type(size.x) ~= "number" or type(size.y) ~= "number" then
    return
  end
  if type(dispatcher.resize) ~= "function" then
    return
  end

  local maxWidth = math.floor(monitor.width * 0.65)
  local maxHeight = math.floor(monitor.height * 0.65)
  local width = math.min(size.x, maxWidth)
  local height = math.min(size.y, maxHeight)

  if width < size.x or height < size.y then
    hl.dispatch(dispatcher.resize({
      window = window,
      x = width,
      y = height,
      relative = false,
    }))
  end
end

function M.active()
  return state.window ~= nil
end

function M.move(workspace)
  local dispatcher = windowDispatcher()
  if dispatcher == nil
    or type(dispatcher.move) ~= "function"
    or type(dispatcher.float) ~= "function"
    or type(hl.dispatch) ~= "function" then
    return { ok = false }
  end

  local window = state.window
  if window == nil then
    if type(hl.get_active_window) ~= "function" then
      return { ok = false }
    end

    window = hl.get_active_window()
    if window == nil then
      return { ok = false }
    end

    state.window = window
    state.was_floating = window.floating == true

    if not state.was_floating then
      hl.dispatch(dispatcher.float({ window = window, action = "enable" }))
      shrinkForCarry(window, dispatcher)
    end
  end

  local result = hl.dispatch(dispatcher.move({
    window = window,
    workspace = workspace,
    follow = true,
  }))

  -- Position changes do not resize the client, and re-centering keeps the
  -- carried window usable when the destination workspace is on another monitor.
  if type(dispatcher.center) == "function" then
    hl.dispatch(dispatcher.center({ window = window }))
  end

  return result
end

function M.finish()
  local window = state.window
  if window == nil then
    return false
  end

  local dispatcher = windowDispatcher()
  local wasFloating = state.was_floating
  reset()

  if not wasFloating
    and dispatcher ~= nil
    and type(dispatcher.float) == "function"
    and type(hl.dispatch) == "function" then
    hl.dispatch(dispatcher.float({ window = window, action = "disable" }))
  end

  return true
end

return M
