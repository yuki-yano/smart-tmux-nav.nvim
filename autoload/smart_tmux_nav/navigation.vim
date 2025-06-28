" Navigation logic for smart-tmux-nav

" Script initialization guard
if exists('g:loaded_smart_tmux_nav_navigation')
  finish
endif
let g:loaded_smart_tmux_nav_navigation = 1

" Module state
let s:state = {
      \ 'config': {},
      \ 'in_tmux': !empty($TMUX),
      \ 'tmux_script_checked': 0,
      \ 'tmux_script_available': 0,
      \ }

" Constants
let s:DIRECTION_MAP = {
      \ 'h': 'left',
      \ 'j': 'down',
      \ 'k': 'up',
      \ 'l': 'right',
      \ }

" Utility: Get non-floating windows
function! s:get_normal_windows() abort
  let windows = []
  " In Vim, we use window numbers instead of IDs for simplicity
  for win in range(1, winnr('$'))
    call add(windows, win)
  endfor
  return windows
endfunction

" Utility: Get window bounds information
function! s:get_window_bounds(win) abort
  " Save current window
  let saved_win = winnr()
  
  " Switch to target window to get its info
  execute a:win . 'wincmd w'
  
  " Get window dimensions
  let width = winwidth(0)
  let height = winheight(0)
  
  " Calculate absolute position
  " For Vim, we need a different approach since we don't have window position APIs
  let abs_row = 1
  let abs_col = 1
  
  " Count windows to the left and above
  let win_layout = winlayout()
  
  " Simple approach: calculate based on window number and layout
  " This is a simplified version that works for common layouts
  for w in range(1, a:win - 1)
    let saved = winnr()
    execute w . 'wincmd w'
    
    " Check if this window is to the left or above
    let w_line = line('w0')
    let w_col = virtcol('.')
    
    execute a:win . 'wincmd w'
    let cur_line = line('w0')
    let cur_col = virtcol('.')
    
    execute saved . 'wincmd w'
    
    " If window is in same row but to the left
    if abs(w_line - cur_line) < 3
      let abs_col += winwidth(w) + 1
    " If window is above
    elseif w_line < cur_line
      let abs_row += winheight(w) + 1
    endif
  endfor
  
  " Restore original window
  execute saved_win . 'wincmd w'

  return {
        \ 'window': a:win,
        \ 'row': abs_row,
        \ 'col': abs_col,
        \ 'width': width,
        \ 'height': height,
        \ 'bottom': abs_row + height,
        \ 'right': abs_col + width,
        \ }
endfunction

" Debug logging
function! s:debug_log(msg, ...) abort
  if s:state.config.debug
    let args = a:000
    let formatted = a:msg
    for i in range(len(args))
      let formatted = substitute(formatted, '%s', string(args[i]), '')
    endfor
    echom '[smart-tmux-nav] ' . formatted
  endif
endfunction

" Check if tmux script is available
function! s:check_tmux_script() abort
  if s:state.tmux_script_checked
    return s:state.tmux_script_available
  endif

  let s:state.tmux_script_checked = 1
  let script_path = exepath('tmux-smart-switch-pane')
  let s:state.tmux_script_available = !empty(script_path)

  if !s:state.tmux_script_available
    call s:debug_log('tmux-smart-switch-pane not found in PATH')
  else
    call s:debug_log('tmux-smart-switch-pane found at: %s', script_path)
  endif

  return s:state.tmux_script_available
endfunction

" Check if current window is at the edge in given direction
function! s:is_at_edge(direction) abort
  let windows = s:get_normal_windows()

  " Single window is always at edge
  if len(windows) <= 1
    return 1
  endif

  " Save current window
  let current_win = winnr()

  " Try to move in the specified direction
  execute 'noautocmd wincmd ' . a:direction

  " Check if we actually moved to a different window
  let new_win = winnr()

  " Restore original window if we moved
  if current_win != new_win
    execute current_win . 'wincmd w'
  endif

  " If the window didn't change, we're at the edge
  return current_win == new_win
endfunction

" Calculate total content area height (all windows)
function! s:calculate_total_height() abort
  let windows = s:get_normal_windows()
  let max_bottom = 0

  for win in windows
    let bounds = s:get_window_bounds(win)
    if bounds.bottom > max_bottom
      let max_bottom = bounds.bottom
    endif
  endfor

  return max_bottom
endfunction

" Check if windows are arranged horizontally (side by side)
function! s:is_horizontal_layout(windows) abort
  if len(a:windows) <= 1
    return 0
  endif

  " Get bounds for first window
  let first_bounds = s:get_window_bounds(a:windows[0])
  let first_col = first_bounds.col
  
  " Check if any two windows have different column positions
  for i in range(1, len(a:windows) - 1)
    let bounds = s:get_window_bounds(a:windows[i])
    if bounds.col != first_col
      return 1  " Found windows in different columns = horizontal layout
    endif
  endfor

  return 0  " All windows in same column = vertical layout
endfunction

" Find the best window based on cursor position and direction
function! s:select_window_by_cursor_position(cursor_y_percent, cursor_x_percent, direction, is_cycle) abort
  let windows = s:get_normal_windows()

  if len(windows) <= 1
    if len(windows) == 1
      execute windows[0] . 'wincmd w'
    endif
    return
  endif

  " Handle cycle movement - select window at opposite edge considering cursor position
  if a:is_cycle
    " Calculate target position based on cursor percentages
    let total_height = &lines - &cmdheight
    let total_width = &columns
    let target_row = float2nr(a:cursor_y_percent * total_height / 100.0)
    let target_col = float2nr(a:cursor_x_percent * total_width / 100.0)

    if a:direction == 'U'
      " Cycling up: select bottommost window that aligns with cursor X
      let candidates = []
      let max_bottom = -1

      " Find the bottommost row
      for win in windows
        let bounds = s:get_window_bounds(win)
        if bounds.bottom > max_bottom
          let max_bottom = bounds.bottom
        endif
      endfor

      " Get all windows at the bottom
      for win in windows
        let bounds = s:get_window_bounds(win)
        if bounds.bottom == max_bottom
          call add(candidates, win)
        endif
      endfor

      " Select the one that best matches cursor X position
      let best_win = candidates[0]
      let best_distance = 999999
      for win in candidates
        let bounds = s:get_window_bounds(win)
        let distance = abs((bounds.col + bounds.width / 2) - target_col)
        if distance < best_distance
          let best_distance = distance
          let best_win = win
        endif
      endfor
      execute best_win . 'wincmd w'
      return
    elseif a:direction == 'D'
      " Cycling down: select topmost window that aligns with cursor X
      let candidates = []
      let min_top = 999999

      " Find the topmost row
      for win in windows
        let bounds = s:get_window_bounds(win)
        if bounds.row < min_top
          let min_top = bounds.row
        endif
      endfor

      " Get all windows at the top
      for win in windows
        let bounds = s:get_window_bounds(win)
        if bounds.row == min_top
          call add(candidates, win)
        endif
      endfor

      " Select the one that best matches cursor X position
      let best_win = candidates[0]
      let best_distance = 999999
      for win in candidates
        let bounds = s:get_window_bounds(win)
        let distance = abs((bounds.col + bounds.width / 2) - target_col)
        if distance < best_distance
          let best_distance = distance
          let best_win = win
        endif
      endfor
      execute best_win . 'wincmd w'
      return
    elseif a:direction == 'L'
      " Cycling left: select rightmost window that aligns with cursor Y
      let candidates = []
      let max_right = -1

      " Find the rightmost column
      for win in windows
        let bounds = s:get_window_bounds(win)
        if bounds.right > max_right
          let max_right = bounds.right
        endif
      endfor

      " Get all windows at the right edge
      for win in windows
        let bounds = s:get_window_bounds(win)
        if bounds.right == max_right
          call add(candidates, win)
        endif
      endfor

      " Select the one that best matches cursor Y position
      let best_win = candidates[0]
      let best_distance = 999999
      for win in candidates
        let bounds = s:get_window_bounds(win)
        let distance = abs((bounds.row + bounds.height / 2) - target_row)
        if distance < best_distance
          let best_distance = distance
          let best_win = win
        endif
      endfor
      execute best_win . 'wincmd w'
      return
    elseif a:direction == 'R'
      " Cycling right: select leftmost window that aligns with cursor Y
      let candidates = []
      let min_left = 999999

      " Find the leftmost column
      for win in windows
        let bounds = s:get_window_bounds(win)
        if bounds.col < min_left
          let min_left = bounds.col
        endif
      endfor

      " Get all windows at the left edge
      for win in windows
        let bounds = s:get_window_bounds(win)
        if bounds.col == min_left
          call add(candidates, win)
        endif
      endfor

      " Select the one that best matches cursor Y position
      let best_win = candidates[0]
      let best_distance = 999999
      for win in candidates
        let bounds = s:get_window_bounds(win)
        let distance = abs((bounds.row + bounds.height / 2) - target_row)
        if distance < best_distance
          let best_distance = distance
          let best_win = win
        endif
      endfor
      execute best_win . 'wincmd w'
      return
    endif
  endif

  " Normal (non-cycle) movement: use cursor position
  " Calculate target position in Vim's coordinate system
  let total_height = &lines - &cmdheight
  let total_width = &columns
  let target_row = float2nr(a:cursor_y_percent * total_height / 100.0)
  let target_col = float2nr(a:cursor_x_percent * total_width / 100.0)

  " Find the best matching window
  let best_window = 0
  let best_distance = 999999

  for win in windows
    let bounds = s:get_window_bounds(win)

    " Check if the target position falls within this window
    if target_row >= bounds.row && target_row < bounds.bottom &&
          \ target_col >= bounds.col && target_col < bounds.right
      execute win . 'wincmd w'
      return
    endif

    " Calculate distance to window center for fallback
    let win_center_row = bounds.row + bounds.height / 2
    let win_center_col = bounds.col + bounds.width / 2
    let distance = abs(target_row - win_center_row) + abs(target_col - win_center_col)

    if distance < best_distance
      let best_distance = distance
      let best_window = win
    endif
  endfor

  " If no exact match, use the closest window
  if best_window
    execute best_window . 'wincmd w'
  endif
endfunction

" Navigate within Vim
function! s:navigate_within_vim(direction) abort
  " Always use standard vim navigation for consistency
  execute 'wincmd ' . a:direction
endfunction

" Initialize the module
function! smart_tmux_nav#navigation#init(config) abort
  let s:state.config = a:config
  let s:state.in_tmux = !empty($TMUX)
  call s:debug_log('Initialized with config: %s', string(a:config))
endfunction

" Public: Check if running in tmux
function! smart_tmux_nav#navigation#in_tmux() abort
  return s:state.in_tmux
endfunction

" Public: Main navigation function
function! smart_tmux_nav#navigation#navigate(direction) abort
  call s:debug_log('Navigate called with direction: %s', a:direction)

  " Outside tmux: always use vim navigation
  if !smart_tmux_nav#navigation#in_tmux()
    execute 'wincmd ' . a:direction
    return
  endif

  " At window edge: delegate to tmux
  if s:is_at_edge(a:direction)
    let tmux_direction = get(s:DIRECTION_MAP, a:direction, '')
    if !empty(tmux_direction)
      " Check if tmux script is available
      if !s:check_tmux_script()
        echohl ErrorMsg
        echo 'smart-tmux-nav: tmux-smart-switch-pane not found in PATH!'
        echo 'Please run the install script or manually copy the script to your PATH.'
        echo 'See :help smart-tmux-nav-installation for details.'
        echohl None
        return
      endif

      call s:debug_log('At edge, calling tmux script: tmux-smart-switch-pane %s', tmux_direction)
      let result = system('tmux-smart-switch-pane ' . tmux_direction)
      if v:shell_error != 0
        echohl ErrorMsg
        echo printf('tmux navigation failed: %s', result)
        echohl None
      endif
    endif
  else
    " Not at edge: navigate within vim
    call s:navigate_within_vim(a:direction)
  endif
endfunction

" Handle tmux environment variable for window selection
function! smart_tmux_nav#navigation#process_tmux_window_selection() abort
  " Check for tmux environment variables
  let cursor_y_result = system('tmux show-environment NVIM_CURSOR_Y 2>/dev/null')
  let cursor_x_result = system('tmux show-environment NVIM_CURSOR_X 2>/dev/null')
  let direction_result = system('tmux show-environment NVIM_SELECT_DIRECTION 2>/dev/null')
  let is_cycle_result = system('tmux show-environment NVIM_IS_CYCLE 2>/dev/null')

  if v:shell_error == 0 && !empty(cursor_y_result)
    " Extract values
    let cursor_y_match = matchlist(cursor_y_result, 'NVIM_CURSOR_Y=\(\d\+\)')
    let cursor_x_match = matchlist(cursor_x_result, 'NVIM_CURSOR_X=\(\d\+\)')
    let direction_match = matchlist(direction_result, 'NVIM_SELECT_DIRECTION=\(\w\)')
    let is_cycle_match = matchlist(is_cycle_result, 'NVIM_IS_CYCLE=\(\w\+\)')

    if len(cursor_y_match) > 1 && len(cursor_x_match) > 1 && len(direction_match) > 1
      let cursor_y_percent = str2nr(cursor_y_match[1])
      let cursor_x_percent = str2nr(cursor_x_match[1])
      let direction = direction_match[1]
      let is_cycle = len(is_cycle_match) > 1 && is_cycle_match[1] == 'true'

      call s:debug_log(
            \ 'Processing tmux window selection: cursor=(%s%%, %s%%), direction=%s, cycle=%s',
            \ cursor_x_percent,
            \ cursor_y_percent,
            \ direction,
            \ is_cycle)

      " Use cursor position with cycle information
      call s:select_window_by_cursor_position(cursor_y_percent, cursor_x_percent, direction, is_cycle)

      " Clear the environment variables
      call system('tmux set-environment -u NVIM_CURSOR_Y')
      call system('tmux set-environment -u NVIM_CURSOR_X')
      call system('tmux set-environment -u NVIM_SELECT_DIRECTION')
      call system('tmux set-environment -u NVIM_IS_CYCLE')
    endif
  endif
endfunction