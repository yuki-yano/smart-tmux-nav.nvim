" Tmux integration for smart-tmux-nav

" Script initialization guard
if exists('g:loaded_smart_tmux_nav_tmux')
  finish
endif
let g:loaded_smart_tmux_nav_tmux = 1

" Setup tmux-specific commands and autocmds
function! smart_tmux_nav#tmux#setup(config) abort
  " Auto-check for window selection on focus
  augroup SmartTmuxNavigation
    autocmd!
    autocmd FocusGained * call smart_tmux_nav#navigation#process_tmux_window_selection()
  augroup END
endfunction