" Tmux integration for smart-tmux-nav

" Script initialization guard
if exists('g:loaded_smart_tmux_nav_tmux')
  finish
endif
let g:loaded_smart_tmux_nav_tmux = 1

" Setup tmux-specific commands and autocmds
function! smart_tmux_nav#tmux#setup(config) abort
  " Command for tmux to call when switching to Vim pane
  command! -nargs=1 TmuxSelectWindow call s:tmux_select_window(<f-args>)

  " Auto-check for window selection on focus
  augroup SmartTmuxNavigation
    autocmd!
    autocmd FocusGained * call smart_tmux_nav#navigation#process_tmux_window_selection()
  augroup END
endfunction

" Handle TmuxSelectWindow command (deprecated)
function! s:tmux_select_window(args) abort
  " This command is handled by FocusGained event now
  " Clear any command line output
  echo ""
endfunction