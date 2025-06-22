local smart_tmux_nav = require('smart-tmux-nav')

describe('smart-tmux-nav', function()
  before_each(function()
    -- Reset any state
    vim.g.smart_tmux_nav_configured = nil
  end)

  describe('setup', function()
    it('should initialize with default configuration', function()
      smart_tmux_nav.setup()
      local config = smart_tmux_nav.get_config()

      assert.is_true(config.enable)
      assert.is_table(config.keybindings)
      assert.equals('<C-h>', config.keybindings.left)
      assert.equals('<C-j>', config.keybindings.down)
      assert.equals('<C-k>', config.keybindings.up)
      assert.equals('<C-l>', config.keybindings.right)
    end)

    it('should accept custom configuration', function()
      smart_tmux_nav.setup({
        enable = false,
        debug = true,
        keybindings = {
          left = '<M-h>',
          down = '<M-j>',
          up = '<M-k>',
          right = '<M-l>',
        },
      })

      local config = smart_tmux_nav.get_config()
      assert.is_false(config.enable)
      assert.is_true(config.debug)
      assert.equals('<M-h>', config.keybindings.left)
    end)

    it('should mark plugin as configured', function()
      assert.is_nil(vim.g.smart_tmux_nav_configured)
      smart_tmux_nav.setup()
      assert.is_true(vim.g.smart_tmux_nav_configured)
    end)
  end)

  describe('navigation', function()
    it('should have navigate function', function()
      assert.is_function(smart_tmux_nav.navigate)
    end)

    -- Note: Actual navigation testing requires mocking vim windows
    -- and tmux environment, which is complex for integration tests
  end)
end)
