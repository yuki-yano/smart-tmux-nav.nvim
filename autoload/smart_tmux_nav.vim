" smart-tmux-nav.vim: Seamless navigation between tmux panes and Vim windows

" Script initialization guard
if exists('g:loaded_smart_tmux_nav_autoload')
  finish
endif
let g:loaded_smart_tmux_nav_autoload = 1

" Default configuration
let s:default_config = {
      \ 'enable': 1,
      \ 'keybindings': {
      \   'left': '<C-h>',
      \   'down': '<C-j>',
      \   'up': '<C-k>',
      \   'right': '<C-l>',
      \ },
      \ 'modes': ['n', 't'],
      \ 'debug': 0,
      \ }

" Current configuration
let s:config = {}

" Merge user config with defaults
function! s:merge_config(user_config) abort
  let s:config = deepcopy(s:default_config)
  if type(a:user_config) == type({})
    for [key, value] in items(a:user_config)
      if has_key(s:config, key)
        if type(value) == type({}) && type(s:config[key]) == type({})
          call extend(s:config[key], value)
        else
          let s:config[key] = value
        endif
      else
        let s:config[key] = value
      endif
    endfor
  endif
  return s:config
endfunction

" Setup function
function! smart_tmux_nav#setup(...) abort
  " Mark as configured to prevent auto-setup
  let g:smart_tmux_nav_configured = 1

  let user_config = a:0 > 0 ? a:1 : {}
  call s:merge_config(user_config)

  if !s:config.enable
    return
  endif

  " Initialize navigation module
  call smart_tmux_nav#navigation#init(s:config)

  " Setup keybindings if enabled
  if type(s:config.keybindings) == type({})
    let direction_map = {'left': 'h', 'down': 'j', 'up': 'k', 'right': 'l'}
    for [direction, key] in items(s:config.keybindings)
      if !empty(key) && has_key(direction_map, direction)
        let vim_direction = direction_map[direction]
        for mode in s:config.modes
          execute printf('%snoremap <silent> %s :call smart_tmux_nav#navigate("%s")<CR>',
                \ mode, key, vim_direction)
        endfor
      endif
    endfor
  endif

  " Setup tmux integration commands
  call smart_tmux_nav#tmux#setup(s:config)
endfunction

" Public API: Navigate
function! smart_tmux_nav#navigate(direction) abort
  call smart_tmux_nav#navigation#navigate(a:direction)
endfunction

" Public API: Get config
function! smart_tmux_nav#get_config() abort
  return s:config
endfunction