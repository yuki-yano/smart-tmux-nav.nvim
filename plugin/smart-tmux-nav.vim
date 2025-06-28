" smart-tmux-nav.vim plugin initialization
" This file is automatically loaded by Vim

" Only load once
if exists('g:loaded_smart_tmux_nav')
  finish
endif
let g:loaded_smart_tmux_nav = 1

" Initialize the plugin (without automatic keybindings)
call smart_tmux_nav#init()

" Define <Plug> mappings
nnoremap <silent> <Plug>SmartTmuxNavLeft  :<C-U>call smart_tmux_nav#navigate('h')<CR>
nnoremap <silent> <Plug>SmartTmuxNavDown  :<C-U>call smart_tmux_nav#navigate('j')<CR>
nnoremap <silent> <Plug>SmartTmuxNavUp    :<C-U>call smart_tmux_nav#navigate('k')<CR>
nnoremap <silent> <Plug>SmartTmuxNavRight :<C-U>call smart_tmux_nav#navigate('l')<CR>

" Terminal mode mappings
if has('terminal')
  tnoremap <silent> <Plug>SmartTmuxNavLeft  <C-\><C-N>:<C-U>call smart_tmux_nav#navigate('h')<CR>
  tnoremap <silent> <Plug>SmartTmuxNavDown  <C-\><C-N>:<C-U>call smart_tmux_nav#navigate('j')<CR>
  tnoremap <silent> <Plug>SmartTmuxNavUp    <C-\><C-N>:<C-U>call smart_tmux_nav#navigate('k')<CR>
  tnoremap <silent> <Plug>SmartTmuxNavRight <C-\><C-N>:<C-U>call smart_tmux_nav#navigate('l')<CR>
endif

" Commands
command! -nargs=1 TmuxSelectWindow call smart_tmux_nav#tmux#select_window(<f-args>)