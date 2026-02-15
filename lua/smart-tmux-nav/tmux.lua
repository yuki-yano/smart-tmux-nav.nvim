-- Tmux integration for smart-tmux-nav
local M = {}

-- Setup tmux-specific commands and autocmds
function M.setup(_config)
  -- Command for tmux to call when switching to Neovim pane
  vim.api.nvim_create_user_command('TmuxSelectWindow', function(_opts)
    -- This command is handled by FocusGained event now
    vim.schedule(function()
      vim.cmd('echo ""')
    end)
  end, {
    nargs = 1,
    desc = 'Select Neovim window based on cursor percentage (deprecated, use FocusGained)',
  })

  if vim.env.TMUX == nil then
    return
  end

  local nav = require('smart-tmux-nav.navigation')

  -- Auto-check for window selection on focus
  vim.api.nvim_create_autocmd('FocusGained', {
    group = vim.api.nvim_create_augroup('SmartTmuxNavigation', { clear = true }),
    callback = nav.process_tmux_window_selection,
    desc = 'Process tmux window selection on focus',
  })
end

return M
