# smart-tmux-nav.nvim

Seamless navigation between tmux panes and Neovim windows with cursor awareness.

## Features

- **Seamless Navigation**: Use the same keybindings to navigate between tmux panes and Neovim windows
- **Cursor-Aware**: When switching from tmux to Neovim, selects the window that best matches your cursor position
- **Cycle Support**: Navigate through panes in a cycle - when you reach an edge, wrap around to the opposite side
- **Customizable**: Configure keybindings, debug mode, and more

## Requirements

- Neovim >= 0.7.0
- tmux >= 2.0
- bash (for the tmux script)

## Installation

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  'yuki-yano/smart-tmux-nav.nvim',
  lazy = false,
  build = './install.sh',  -- Installs tmux-smart-switch-pane to your PATH
  config = function()
    require('smart-tmux-nav').setup()
  end,
}
```

## Setup

This plugin requires two components:
1. The Neovim plugin (installed via your plugin manager)
2. The tmux script `tmux-smart-switch-pane` (needs to be in your PATH)

### Installing the tmux script

#### Option 1: Automatic Installation (Recommended)

If you're using lazy.nvim with the `build = './install.sh'` option, the script will be installed automatically. Otherwise, you can run the install script manually:

```bash
cd /path/to/smart-tmux-nav.nvim
./install.sh
```

The install script will:
- Find or create a suitable directory in your PATH (~/.local/bin or ~/bin)
- Copy the tmux script to that directory
- Make it executable
- Show you the tmux configuration to add

#### Option 2: Manual Installation

If you prefer to install manually:

```bash
# Copy the script to a directory in your PATH
cp /path/to/smart-tmux-nav.nvim/bin/tmux-smart-switch-pane ~/.local/bin/
chmod +x ~/.local/bin/tmux-smart-switch-pane

# Or if you prefer /usr/local/bin
sudo cp /path/to/smart-tmux-nav.nvim/bin/tmux-smart-switch-pane /usr/local/bin/
sudo chmod +x /usr/local/bin/tmux-smart-switch-pane
```

### tmux Configuration

Add the following to your `~/.tmux.conf`:

```bash
# Smart pane switching with awareness of Neovim
bind -n C-h if -F "#{pane_current_command} =~ '(n?vim?)'" \
  "send-keys C-h" \
  "run-shell 'tmux-smart-switch-pane left'"

bind -n C-j if -F "#{pane_current_command} =~ '(n?vim?)'" \
  "send-keys C-j" \
  "run-shell 'tmux-smart-switch-pane down'"

bind -n C-k if -F "#{pane_current_command} =~ '(n?vim?)'" \
  "send-keys C-k" \
  "run-shell 'tmux-smart-switch-pane up'"

bind -n C-l if -F "#{pane_current_command} =~ '(n?vim?)'" \
  "send-keys C-l" \
  "run-shell 'tmux-smart-switch-pane right'"
```

After adding the configuration, reload tmux:

```bash
tmux source-file ~/.tmux.conf
```

## Configuration

### Default Configuration

```lua
require('smart-tmux-nav').setup({
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
})
```

### Disable Default Keybindings

If you want to set up your own keybindings:

```lua
require('smart-tmux-nav').setup({
  keybindings = false,
})

-- Set up custom keybindings
vim.keymap.set('n', '<M-h>', function() require('smart-tmux-nav').navigate('h') end)
vim.keymap.set('n', '<M-j>', function() require('smart-tmux-nav').navigate('j') end)
vim.keymap.set('n', '<M-k>', function() require('smart-tmux-nav').navigate('k') end)
vim.keymap.set('n', '<M-l>', function() require('smart-tmux-nav').navigate('l') end)
```

### Debug Mode

Enable debug mode to see what's happening:

```lua
require('smart-tmux-nav').setup({
  debug = true,
})
```

## How It Works

1. **Within Neovim**: When you press a navigation key (e.g., `<C-h>`), the plugin checks if you're at a window edge
2. **At Window Edge**: If at an edge, it calls the tmux script to switch panes
3. **Cursor Awareness**: The tmux script records your cursor position and finds the best matching pane
4. **Window Selection**: When entering a Neovim pane, it selects the window that best matches your previous cursor position

## Troubleshooting

### Script Not Found

If you get an error about `tmux-smart-switch-pane` not being found:

1. Check if the script exists in the plugin directory:
   ```bash
   find /path/to/nvim/plugins -name "tmux-smart-switch-pane" 2>/dev/null
   ```

2. Copy it to your PATH:
   ```bash
   cp /path/to/smart-tmux-nav.nvim/bin/tmux-smart-switch-pane ~/.local/bin/
   chmod +x ~/.local/bin/tmux-smart-switch-pane
   ```

### Navigation Not Working

1. Ensure tmux key bindings are properly configured
2. Check that the plugin is loaded: `:lua print(vim.g.loaded_smart_tmux_nav)`
3. Enable debug mode to see what's happening
4. Verify tmux version: `tmux -V` (should be >= 2.0)

## API

### Functions

- `require('smart-tmux-nav').setup(config)` - Initialize the plugin with configuration
- `require('smart-tmux-nav').navigate(direction)` - Navigate in the given direction ('h', 'j', 'k', 'l')

## License

MIT
