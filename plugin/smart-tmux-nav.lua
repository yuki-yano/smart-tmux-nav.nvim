-- smart-tmux-nav.nvim plugin initialization
-- This file is automatically loaded by Neovim

-- Only load once
if vim.g.loaded_smart_tmux_nav then
  return
end
vim.g.loaded_smart_tmux_nav = true

-- Defer setup to allow user configuration
local function auto_setup()
  -- Only auto-setup if user hasn't called setup manually
  if not vim.g.smart_tmux_nav_configured then
    require('smart-tmux-nav').setup()
  end
end

-- Check if VimEnter has already fired (for lazy-loaded plugins)
if vim.v.vim_did_enter == 1 then
  vim.defer_fn(auto_setup, 0)
else
  vim.api.nvim_create_autocmd('VimEnter', {
    group = vim.api.nvim_create_augroup('SmartTmuxNavSetup', { clear = true }),
    callback = auto_setup,
    desc = 'Auto-setup smart-tmux-nav if not configured',
  })
end
