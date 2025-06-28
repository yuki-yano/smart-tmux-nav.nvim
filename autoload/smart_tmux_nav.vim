" smart-tmux-nav.vim: Seamless navigation between tmux panes and Vim windows

" Script initialization guard
if exists('g:loaded_smart_tmux_nav_autoload')
  finish
endif
let g:loaded_smart_tmux_nav_autoload = 1

" Initialize function
function! smart_tmux_nav#init() abort
  " Get configuration from global variables
  let config = {
        \ 'debug': get(g:, 'smart_tmux_nav_debug', 0),
        \ }

  " Initialize navigation module
  call smart_tmux_nav#navigation#init(config)

  " Setup tmux integration commands
  call smart_tmux_nav#tmux#setup(config)
endfunction

" Public API: Navigate
function! smart_tmux_nav#navigate(direction) abort
  call smart_tmux_nav#navigation#navigate(a:direction)
endfunction