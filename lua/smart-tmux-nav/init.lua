-- smart-tmux-nav.nvim: Seamless navigation between tmux panes and Neovim windows
local M = {}

-- Default configuration
local default_config = {
  -- Enable the plugin
  enable = true,
  -- Custom keybindings (set to false to disable default mappings)
  keybindings = {
    left = '<C-h>',
    down = '<C-j>',
    up = '<C-k>',
    right = '<C-l>',
  },
  -- Modes for keybindings
  modes = { 'n', 't' },
  -- Enable debug mode
  debug = false,
}

-- Current configuration
local config = {}

-- Merge user config with defaults
local function merge_config(user_config)
  config = vim.tbl_deep_extend('force', default_config, user_config or {})
  return config
end

-- Setup function
function M.setup(user_config)
  -- Mark as configured to prevent auto-setup
  vim.g.smart_tmux_nav_configured = true

  merge_config(user_config)

  if not config.enable then
    return
  end

  -- Load navigation module
  local nav = require('smart-tmux-nav.navigation')
  nav.init(config)

  -- Setup keybindings if enabled
  if config.keybindings then
    for direction, key in pairs(config.keybindings) do
      if key then
        local vim_direction = ({ left = 'h', down = 'j', up = 'k', right = 'l' })[direction]
        if vim_direction then
          vim.keymap.set(config.modes, key, function()
            nav.navigate(vim_direction)
          end, { silent = true, desc = 'Navigate ' .. direction })
        end
      end
    end
  end

  -- Setup tmux integration commands
  require('smart-tmux-nav.tmux').setup(config)
end

-- Public API
M.navigate = function(direction)
  local nav = require('smart-tmux-nav.navigation')
  nav.navigate(direction)
end

M.get_config = function()
  return config
end

return M
