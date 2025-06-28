" smart-tmux-nav.vim plugin initialization
" This file is automatically loaded by Vim

" Only load once
if exists('g:loaded_smart_tmux_nav')
  finish
endif
let g:loaded_smart_tmux_nav = 1

" Defer setup to allow user configuration
function! s:auto_setup() abort
  " Only auto-setup if user hasn't called setup manually
  if !exists('g:smart_tmux_nav_configured')
    call smart_tmux_nav#setup()
  endif
endfunction

" Check if VimEnter has already fired (for lazy-loaded plugins)
if v:vim_did_enter
  call timer_start(0, {-> s:auto_setup()})
else
  augroup SmartTmuxNavSetup
    autocmd!
    autocmd VimEnter * call s:auto_setup()
  augroup END
endif