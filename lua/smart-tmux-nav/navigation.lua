-- Navigation logic for smart-tmux-nav
local M = {}

-- Module state
local state = {
  config = {},
  in_tmux = vim.env.TMUX ~= nil,
  tmux_script_checked = false,
  tmux_script_available = false,
  window_bounds_cache = nil,
  window_bounds_cache_valid = false,
  normal_window_count_cache = nil,
  normal_window_count_cache_valid = false,
  window_bounds_cache_autocmds_initialized = false,
  pending_tmux_selection_check = true,
}

-- Constants
local DIRECTION_MAP = {
  h = 'left',
  j = 'down',
  k = 'up',
  l = 'right',
}

local TMUX_SELECTION_CLEAR_COMMAND =
  'tmux set-environment -u NVIM_CURSOR_Y \\; '
  .. 'set-environment -u NVIM_CURSOR_X \\; '
  .. 'set-environment -u NVIM_SELECT_DIRECTION \\; '
  .. 'set-environment -u NVIM_IS_CYCLE'

local TMUX_SELECTION_ENV_KEYS = {
  NVIM_CURSOR_Y = true,
  NVIM_CURSOR_X = true,
  NVIM_SELECT_DIRECTION = true,
  NVIM_IS_CYCLE = true,
}

-- Utility: Collect non-floating windows and precompute bounds
local function collect_normal_window_bounds()
  local windows = {}

  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_config(win).relative == '' then
      local pos = vim.api.nvim_win_get_position(win)
      local width = vim.api.nvim_win_get_width(win)
      local height = vim.api.nvim_win_get_height(win)

      windows[#windows + 1] = {
        window = win,
        row = pos[1],
        col = pos[2],
        width = width,
        height = height,
        bottom = pos[1] + height,
        right = pos[2] + width,
      }
    end
  end

  return windows
end

local function collect_normal_window_count()
  local count = 0

  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_config(win).relative == '' then
      count = count + 1
    end
  end

  return count
end

local function invalidate_window_bounds_cache()
  state.window_bounds_cache = nil
  state.window_bounds_cache_valid = false
  state.normal_window_count_cache = nil
  state.normal_window_count_cache_valid = false
end

local function setup_window_bounds_cache_autocmds()
  if state.window_bounds_cache_autocmds_initialized then
    return
  end

  state.window_bounds_cache_autocmds_initialized = true

  vim.api.nvim_create_autocmd({ 'WinResized', 'WinClosed', 'WinNew', 'TabEnter', 'VimResized' }, {
    group = vim.api.nvim_create_augroup('SmartTmuxNavWindowBoundsCache', { clear = true }),
    callback = invalidate_window_bounds_cache,
    desc = 'Invalidate smart-tmux-nav window bounds cache',
  })
end

local function get_normal_window_bounds()
  if state.window_bounds_cache_valid and state.window_bounds_cache then
    return state.window_bounds_cache
  end

  state.window_bounds_cache = collect_normal_window_bounds()
  state.window_bounds_cache_valid = true
  state.normal_window_count_cache = #state.window_bounds_cache
  state.normal_window_count_cache_valid = true
  return state.window_bounds_cache
end

local function get_normal_window_count()
  if state.normal_window_count_cache_valid and state.normal_window_count_cache ~= nil then
    return state.normal_window_count_cache
  end

  state.normal_window_count_cache = collect_normal_window_count()
  state.normal_window_count_cache_valid = true
  return state.normal_window_count_cache
end

local function is_floating_window(win)
  return vim.api.nvim_win_get_config(win).relative ~= ''
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
  -- Single window is always at edge
  if get_normal_window_count() <= 1 then
    return true
  end

  -- Non-destructive edge check using window numbers
  return vim.fn.winnr() == vim.fn.winnr(direction)
end

local function select_cycle_window(windows, direction, target_row, target_col)
  local best_window = nil
  local best_edge = nil
  local best_distance = math.huge

  for _, bounds in ipairs(windows) do
    local edge
    local distance

    if direction == 'U' then
      edge = bounds.bottom
      distance = math.abs((bounds.col + bounds.width / 2) - target_col)
      if best_edge == nil or edge > best_edge or (edge == best_edge and distance < best_distance) then
        best_edge = edge
        best_distance = distance
        best_window = bounds.window
      end
    elseif direction == 'D' then
      edge = bounds.row
      distance = math.abs((bounds.col + bounds.width / 2) - target_col)
      if best_edge == nil or edge < best_edge or (edge == best_edge and distance < best_distance) then
        best_edge = edge
        best_distance = distance
        best_window = bounds.window
      end
    elseif direction == 'L' then
      edge = bounds.right
      distance = math.abs((bounds.row + bounds.height / 2) - target_row)
      if best_edge == nil or edge > best_edge or (edge == best_edge and distance < best_distance) then
        best_edge = edge
        best_distance = distance
        best_window = bounds.window
      end
    elseif direction == 'R' then
      edge = bounds.col
      distance = math.abs((bounds.row + bounds.height / 2) - target_row)
      if best_edge == nil or edge < best_edge or (edge == best_edge and distance < best_distance) then
        best_edge = edge
        best_distance = distance
        best_window = bounds.window
      end
    end
  end

  return best_window
end

-- Find the best window based on cursor position and direction
local function select_window_by_cursor_position(cursor_y_percent, cursor_x_percent, direction, is_cycle)
  local windows = get_normal_window_bounds()

  if #windows <= 1 then
    if #windows == 1 then
      vim.api.nvim_set_current_win(windows[1].window)
    end
    return
  end

  -- Calculate target position based on cursor percentages
  local total_height = vim.o.lines - vim.o.cmdheight
  local total_width = vim.o.columns
  local target_row = math.floor(cursor_y_percent * total_height / 100)
  local target_col = math.floor(cursor_x_percent * total_width / 100)

  -- Handle cycle movement - select window at opposite edge considering cursor position
  if is_cycle then
    local cycle_window = select_cycle_window(windows, direction, target_row, target_col)
    if cycle_window then
      vim.api.nvim_set_current_win(cycle_window)
      return
    end
  end

  -- Find the best matching window
  local best_window = nil
  local best_distance = math.huge

  for _, bounds in ipairs(windows) do
    -- Check if the target position falls within this window
    if
      target_row >= bounds.row
      and target_row < bounds.bottom
      and target_col >= bounds.col
      and target_col < bounds.right
    then
      vim.api.nvim_set_current_win(bounds.window)
      return
    end

    -- Calculate distance to window center for fallback
    local win_center_row = bounds.row + bounds.height / 2
    local win_center_col = bounds.col + bounds.width / 2
    local distance = math.abs(target_row - win_center_row) + math.abs(target_col - win_center_col)

    if distance < best_distance then
      best_distance = distance
      best_window = bounds
    end
  end

  -- If no exact match, use the closest window
  if best_window then
    vim.api.nvim_set_current_win(best_window.window)
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
  state.pending_tmux_selection_check = state.in_tmux
  invalidate_window_bounds_cache()
  setup_window_bounds_cache_autocmds()
  if state.config.debug then
    debug_log('Initialized with config: %s', vim.inspect(config))
  end
end

-- Public: Check if running in tmux
function M.in_tmux()
  return state.in_tmux
end

function M.mark_focus_lost()
  if state.in_tmux then
    state.pending_tmux_selection_check = true
  end
end

-- Helper function to navigate to tmux
local function navigate_to_tmux(direction)
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

    debug_log('Calling tmux script: tmux-smart-switch-pane %s', tmux_direction)
    local result = vim.fn.system('tmux-smart-switch-pane ' .. tmux_direction)
    if vim.v.shell_error ~= 0 then
      vim.notify(string.format('tmux navigation failed: %s', result), vim.log.levels.ERROR)
    end
  end
end

-- Public: Main navigation function
function M.navigate(direction)
  debug_log('Navigate called with direction: %s', direction)

  -- Outside tmux: always use vim navigation
  if not M.in_tmux() then
    vim.cmd('wincmd ' .. direction)
    return
  end

  -- Check if current window is floating and should navigate to tmux
  if state.config.navigate_from_floating then
    local current_win = vim.api.nvim_get_current_win()
    if is_floating_window(current_win) then
      debug_log('In floating window, navigating directly to tmux')
      navigate_to_tmux(direction)
      return
    end
  end

  -- At window edge: delegate to tmux
  if is_at_edge(direction) then
    debug_log('At edge, navigating to tmux')
    navigate_to_tmux(direction)
  else
    -- Not at edge: navigate within vim
    navigate_within_vim(direction)
  end
end

local function clear_tmux_selection_environment()
  vim.fn.system(TMUX_SELECTION_CLEAR_COMMAND)
end

local function parse_tmux_selection_environment(result)
  local env = {}

  for line in result:gmatch('[^\r\n]+') do
    local key, value = line:match('^([A-Za-z_][A-Za-z0-9_]*)=(.*)$')
    if key and TMUX_SELECTION_ENV_KEYS[key] then
      env[key] = value
    end
  end

  return env
end

-- Handle tmux environment variable for window selection
function M.process_tmux_window_selection()
  if not state.in_tmux then
    return
  end

  if not state.pending_tmux_selection_check then
    return
  end
  state.pending_tmux_selection_check = false

  -- Check for tmux environment variables
  local env_result = vim.fn.system('tmux show-environment 2>/dev/null')
  if vim.v.shell_error ~= 0 or env_result == '' then
    return
  end

  local env = parse_tmux_selection_environment(env_result)
  local has_selection = env.NVIM_CURSOR_Y or env.NVIM_CURSOR_X or env.NVIM_SELECT_DIRECTION or env.NVIM_IS_CYCLE
  if not has_selection then
    return
  end

  local cursor_y_percent = tonumber(env.NVIM_CURSOR_Y)
  local cursor_x_percent = tonumber(env.NVIM_CURSOR_X)
  local direction = env.NVIM_SELECT_DIRECTION
  local is_cycle = env.NVIM_IS_CYCLE == 'true'

  if not cursor_y_percent or not cursor_x_percent or not direction then
    debug_log('Skipping window selection: incomplete tmux selection metadata')
    clear_tmux_selection_environment()
    return
  end

  debug_log(
    'Processing tmux window selection: cursor=(%s%%, %s%%), direction=%s, cycle=%s',
    cursor_x_percent,
    cursor_y_percent,
    direction,
    is_cycle
  )

  -- Check if we should skip auto-focus when coming from a floating window
  if state.config.disable_when_floating and is_floating_window(vim.api.nvim_get_current_win()) then
    debug_log('Skipping auto-focus: coming from floating window')
    clear_tmux_selection_environment()
    return
  end

  -- Use cursor position with cycle information
  select_window_by_cursor_position(cursor_y_percent, cursor_x_percent, direction, is_cycle)

  -- Clear the environment variables
  clear_tmux_selection_environment()
end

return M
