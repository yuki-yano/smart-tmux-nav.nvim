-- Navigation logic for smart-tmux-nav
local M = {}

-- Module state
local state = {
  config = {},
  in_tmux = vim.env.TMUX ~= nil,
  tmux_script_checked = false,
  tmux_script_available = false,
}

-- Constants
local DIRECTION_MAP = {
  h = 'left',
  j = 'down',
  k = 'up',
  l = 'right',
}

-- Utility: Get non-floating windows
local function get_normal_windows()
  return vim.tbl_filter(function(win)
    return vim.api.nvim_win_get_config(win).relative == ''
  end, vim.api.nvim_list_wins())
end

-- Utility: Get window bounds information
local function get_window_bounds(win)
  local pos = vim.api.nvim_win_get_position(win)
  local width = vim.api.nvim_win_get_width(win)
  local height = vim.api.nvim_win_get_height(win)

  return {
    window = win,
    row = pos[1],
    col = pos[2],
    width = width,
    height = height,
    bottom = pos[1] + height,
    right = pos[2] + width,
  }
end

-- Debug logging
local function debug_log(msg, ...)
  if state.config.debug then
    vim.notify(string.format('[smart-tmux-nav] ' .. msg, ...), vim.log.levels.DEBUG)
  end
end

-- Check if tmux script is available
local function check_tmux_script()
  if state.tmux_script_checked then
    return state.tmux_script_available
  end

  state.tmux_script_checked = true
  local script_path = vim.fn.exepath('tmux-smart-switch-pane')
  state.tmux_script_available = script_path ~= ''

  if not state.tmux_script_available then
    debug_log('tmux-smart-switch-pane not found in PATH')
  else
    debug_log('tmux-smart-switch-pane found at: %s', script_path)
  end

  return state.tmux_script_available
end

-- Check if current window is at the edge in given direction
local function is_at_edge(direction)
  local windows = get_normal_windows()

  -- Single window is always at edge
  if #windows <= 1 then
    return true
  end

  -- Save current window
  local current_win = vim.api.nvim_get_current_win()

  -- Try to move in the specified direction
  vim.cmd('noautocmd wincmd ' .. direction)

  -- Check if we actually moved to a different window
  local new_win = vim.api.nvim_get_current_win()

  -- Restore original window
  vim.api.nvim_set_current_win(current_win)

  -- If the window didn't change, we're at the edge
  return current_win == new_win
end

-- Calculate total content area height (all windows)
local function calculate_total_height()
  local windows = get_normal_windows()
  local max_bottom = 0

  for _, win in ipairs(windows) do
    local bounds = get_window_bounds(win)
    if bounds.bottom > max_bottom then
      max_bottom = bounds.bottom
    end
  end

  return max_bottom
end

-- Check if windows are arranged horizontally (side by side)
local function is_horizontal_layout(windows)
  if #windows <= 1 then
    return false
  end

  -- Check if any two windows have different column positions
  local first_col = vim.api.nvim_win_get_position(windows[1])[2]
  for i = 2, #windows do
    if vim.api.nvim_win_get_position(windows[i])[2] ~= first_col then
      return true -- Found windows in different columns = horizontal layout
    end
  end

  return false -- All windows in same column = vertical layout
end

-- Find the best window based on cursor position and direction
local function select_window_by_cursor_position(cursor_y_percent, cursor_x_percent, direction, is_cycle)
  local windows = get_normal_windows()

  if #windows <= 1 then
    if #windows == 1 then
      vim.api.nvim_set_current_win(windows[1])
    end
    return
  end

  -- Handle cycle movement - select window at opposite edge considering cursor position
  if is_cycle then
    -- Calculate target position based on cursor percentages
    local total_height = vim.o.lines - vim.o.cmdheight
    local total_width = vim.o.columns
    local target_row = math.floor(cursor_y_percent * total_height / 100)
    local target_col = math.floor(cursor_x_percent * total_width / 100)

    if direction == 'U' then
      -- Cycling up: select bottommost window that aligns with cursor X
      local candidates = {}
      local max_bottom = -1

      -- Find the bottommost row
      for _, win in ipairs(windows) do
        local bounds = get_window_bounds(win)
        if bounds.bottom > max_bottom then
          max_bottom = bounds.bottom
        end
      end

      -- Get all windows at the bottom
      for _, win in ipairs(windows) do
        local bounds = get_window_bounds(win)
        if bounds.bottom == max_bottom then
          table.insert(candidates, win)
        end
      end

      -- Select the one that best matches cursor X position
      local best_win = candidates[1]
      local best_distance = math.huge
      for _, win in ipairs(candidates) do
        local bounds = get_window_bounds(win)
        local distance = math.abs((bounds.col + bounds.width / 2) - target_col)
        if distance < best_distance then
          best_distance = distance
          best_win = win
        end
      end
      vim.api.nvim_set_current_win(best_win)
      return
    elseif direction == 'D' then
      -- Cycling down: select topmost window that aligns with cursor X
      local candidates = {}
      local min_top = math.huge

      -- Find the topmost row
      for _, win in ipairs(windows) do
        local bounds = get_window_bounds(win)
        if bounds.row < min_top then
          min_top = bounds.row
        end
      end

      -- Get all windows at the top
      for _, win in ipairs(windows) do
        local bounds = get_window_bounds(win)
        if bounds.row == min_top then
          table.insert(candidates, win)
        end
      end

      -- Select the one that best matches cursor X position
      local best_win = candidates[1]
      local best_distance = math.huge
      for _, win in ipairs(candidates) do
        local bounds = get_window_bounds(win)
        local distance = math.abs((bounds.col + bounds.width / 2) - target_col)
        if distance < best_distance then
          best_distance = distance
          best_win = win
        end
      end
      vim.api.nvim_set_current_win(best_win)
      return
    elseif direction == 'L' then
      -- Cycling left: select rightmost window that aligns with cursor Y
      local candidates = {}
      local max_right = -1

      -- Find the rightmost column
      for _, win in ipairs(windows) do
        local bounds = get_window_bounds(win)
        if bounds.right > max_right then
          max_right = bounds.right
        end
      end

      -- Get all windows at the right edge
      for _, win in ipairs(windows) do
        local bounds = get_window_bounds(win)
        if bounds.right == max_right then
          table.insert(candidates, win)
        end
      end

      -- Select the one that best matches cursor Y position
      local best_win = candidates[1]
      local best_distance = math.huge
      for _, win in ipairs(candidates) do
        local bounds = get_window_bounds(win)
        local distance = math.abs((bounds.row + bounds.height / 2) - target_row)
        if distance < best_distance then
          best_distance = distance
          best_win = win
        end
      end
      vim.api.nvim_set_current_win(best_win)
      return
    elseif direction == 'R' then
      -- Cycling right: select leftmost window that aligns with cursor Y
      local candidates = {}
      local min_left = math.huge

      -- Find the leftmost column
      for _, win in ipairs(windows) do
        local bounds = get_window_bounds(win)
        if bounds.col < min_left then
          min_left = bounds.col
        end
      end

      -- Get all windows at the left edge
      for _, win in ipairs(windows) do
        local bounds = get_window_bounds(win)
        if bounds.col == min_left then
          table.insert(candidates, win)
        end
      end

      -- Select the one that best matches cursor Y position
      local best_win = candidates[1]
      local best_distance = math.huge
      for _, win in ipairs(candidates) do
        local bounds = get_window_bounds(win)
        local distance = math.abs((bounds.row + bounds.height / 2) - target_row)
        if distance < best_distance then
          best_distance = distance
          best_win = win
        end
      end
      vim.api.nvim_set_current_win(best_win)
      return
    end
  end

  -- Normal (non-cycle) movement: use cursor position
  -- Calculate target position in Neovim's coordinate system
  local total_height = vim.o.lines - vim.o.cmdheight
  local total_width = vim.o.columns
  local target_row = math.floor(cursor_y_percent * total_height / 100)
  local target_col = math.floor(cursor_x_percent * total_width / 100)

  -- Find the best matching window
  local best_window = nil
  local best_distance = math.huge

  for _, win in ipairs(windows) do
    local bounds = get_window_bounds(win)

    -- Check if the target position falls within this window
    if
      target_row >= bounds.row
      and target_row < bounds.bottom
      and target_col >= bounds.col
      and target_col < bounds.right
    then
      vim.api.nvim_set_current_win(win)
      return
    end

    -- Calculate distance to window center for fallback
    local win_center_row = bounds.row + bounds.height / 2
    local win_center_col = bounds.col + bounds.width / 2
    local distance = math.abs(target_row - win_center_row) + math.abs(target_col - win_center_col)

    if distance < best_distance then
      best_distance = distance
      best_window = win
    end
  end

  -- If no exact match, use the closest window
  if best_window then
    vim.api.nvim_set_current_win(best_window)
  end
end

-- Navigate within Vim
local function navigate_within_vim(direction)
  -- Always use standard vim navigation for consistency
  vim.cmd('wincmd ' .. direction)
end

-- Initialize the module
function M.init(config)
  state.config = config
  state.in_tmux = vim.env.TMUX ~= nil
  debug_log('Initialized with config: %s', vim.inspect(config))
end

-- Public: Check if running in tmux
function M.in_tmux()
  return state.in_tmux
end

-- Public: Main navigation function
function M.navigate(direction)
  debug_log('Navigate called with direction: %s', direction)

  -- Outside tmux: always use vim navigation
  if not M.in_tmux() then
    vim.cmd('wincmd ' .. direction)
    return
  end

  -- At window edge: delegate to tmux
  if is_at_edge(direction) then
    local tmux_direction = DIRECTION_MAP[direction]
    if tmux_direction then
      -- Check if tmux script is available
      if not check_tmux_script() then
        vim.notify(
          'smart-tmux-nav: tmux-smart-switch-pane not found in PATH!\n'
            .. 'Please run the install script or manually copy the script to your PATH.\n'
            .. 'See :help smart-tmux-nav-installation for details.',
          vim.log.levels.ERROR
        )
        return
      end

      debug_log('At edge, calling tmux script: tmux-smart-switch-pane %s', tmux_direction)
      local result = vim.fn.system('tmux-smart-switch-pane ' .. tmux_direction)
      if vim.v.shell_error ~= 0 then
        vim.notify(string.format('tmux navigation failed: %s', result), vim.log.levels.ERROR)
      end
    end
  else
    -- Not at edge: navigate within vim
    navigate_within_vim(direction)
  end
end

-- Handle tmux environment variable for window selection
function M.process_tmux_window_selection()
  -- Check for tmux environment variables
  local cursor_y_result = vim.fn.system('tmux show-environment NVIM_CURSOR_Y 2>/dev/null')
  local cursor_x_result = vim.fn.system('tmux show-environment NVIM_CURSOR_X 2>/dev/null')
  local direction_result = vim.fn.system('tmux show-environment NVIM_SELECT_DIRECTION 2>/dev/null')
  local is_cycle_result = vim.fn.system('tmux show-environment NVIM_IS_CYCLE 2>/dev/null')

  if vim.v.shell_error == 0 and cursor_y_result ~= '' then
    -- Extract values
    local cursor_y_percent = cursor_y_result:match('NVIM_CURSOR_Y=(%d+)')
    local cursor_x_percent = cursor_x_result:match('NVIM_CURSOR_X=(%d+)')
    local direction = direction_result:match('NVIM_SELECT_DIRECTION=(%w)')
    local is_cycle = is_cycle_result:match('NVIM_IS_CYCLE=(%w+)') == 'true'

    if cursor_y_percent and cursor_x_percent and direction then
      debug_log(
        'Processing tmux window selection: cursor=(%s%%, %s%%), direction=%s, cycle=%s',
        cursor_x_percent,
        cursor_y_percent,
        direction,
        is_cycle
      )

      -- Use cursor position with cycle information
      select_window_by_cursor_position(tonumber(cursor_y_percent), tonumber(cursor_x_percent), direction, is_cycle)

      -- Clear the environment variables
      vim.fn.system('tmux set-environment -u NVIM_CURSOR_Y')
      vim.fn.system('tmux set-environment -u NVIM_CURSOR_X')
      vim.fn.system('tmux set-environment -u NVIM_SELECT_DIRECTION')
      vim.fn.system('tmux set-environment -u NVIM_IS_CYCLE')
    end
  end
end

return M
