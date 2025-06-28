# smart-tmux-nav.vim

Seamless navigation between tmux panes and Vim windows with cursor awareness.

## Features

- **Seamless Navigation**: Use the same keybindings to navigate between tmux panes and Vim windows
- **Cursor-Aware**: When switching from tmux to Vim, selects the window that best matches your cursor position
- **Cycle Support**: Navigate through panes in a cycle - when you reach an edge, wrap around to the opposite side
- **Customizable**: Configure keybindings, debug mode, and more

## Requirements

- Vim >= 8.0 (with +eval feature)
- tmux >= 2.0
- bash (for the tmux script)

## Installation

### Using vim-plug

```vim
Plug 'yuki-yano/smart-tmux-nav.vim', { 'do': './install.sh' }
```

### Using Vundle

```vim
Plugin 'yuki-yano/smart-tmux-nav.vim'
" After installation, run: ./install.sh from the plugin directory
```

### Manual Installation

```bash
git clone https://github.com/yuki-yano/smart-tmux-nav.vim.git ~/.vim/pack/plugins/start/smart-tmux-nav
cd ~/.vim/pack/plugins/start/smart-tmux-nav
./install.sh
```

## Setup

This plugin requires two components:
1. The Vim plugin (installed via your plugin manager)
2. The tmux script `tmux-smart-switch-pane` (needs to be in your PATH)

### Installing the tmux script

#### Option 1: Automatic Installation (Recommended)

If you're using a plugin manager with the `build`/`do` option, the script will be installed automatically. Otherwise, you can run the install script manually:

```bash
cd /path/to/smart-tmux-nav.vim
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
cp /path/to/smart-tmux-nav.vim/bin/tmux-smart-switch-pane ~/.local/bin/
chmod +x ~/.local/bin/tmux-smart-switch-pane

# Or if you prefer /usr/local/bin
sudo cp /path/to/smart-tmux-nav.vim/bin/tmux-smart-switch-pane /usr/local/bin/
sudo chmod +x /usr/local/bin/tmux-smart-switch-pane
```

### tmux Configuration

Add the following to your `~/.tmux.conf`:

```bash
# Smart pane switching with awareness of Vim
bind -n C-h if -F "#{pane_current_command} =~ 'vim'" \
  "send-keys C-h" \
  "run-shell 'tmux-smart-switch-pane left'"

bind -n C-j if -F "#{pane_current_command} =~ 'vim'" \
  "send-keys C-j" \
  "run-shell 'tmux-smart-switch-pane down'"

bind -n C-k if -F "#{pane_current_command} =~ 'vim'" \
  "send-keys C-k" \
  "run-shell 'tmux-smart-switch-pane up'"

bind -n C-l if -F "#{pane_current_command} =~ 'vim'" \
  "send-keys C-l" \
  "run-shell 'tmux-smart-switch-pane right'"
```

After adding the configuration, reload tmux:

```bash
tmux source-file ~/.tmux.conf
```

## Configuration

Add to your `.vimrc`:

```vim
" Map using the provided <Plug> mappings
nmap <C-h> <Plug>SmartTmuxNavLeft
nmap <C-j> <Plug>SmartTmuxNavDown
nmap <C-k> <Plug>SmartTmuxNavUp
nmap <C-l> <Plug>SmartTmuxNavRight

" If you have terminal mode and want to use it there too
if has('terminal')
  tmap <C-h> <Plug>SmartTmuxNavLeft
  tmap <C-j> <Plug>SmartTmuxNavDown
  tmap <C-k> <Plug>SmartTmuxNavUp
  tmap <C-l> <Plug>SmartTmuxNavRight
endif
```

### Custom Keybindings

You can map to any keys you prefer:

```vim
" Example with Meta/Alt keys
nmap <M-h> <Plug>SmartTmuxNavLeft
nmap <M-j> <Plug>SmartTmuxNavDown
nmap <M-k> <Plug>SmartTmuxNavUp
nmap <M-l> <Plug>SmartTmuxNavRight
```

### Debug Mode

Enable debug mode by setting a global variable:

```vim
" Enable debug logging
let g:smart_tmux_nav_debug = 1
```

## How It Works

1. **Within Vim**: When you press a navigation key (e.g., `<C-h>`), the plugin checks if you're at a window edge
2. **At Window Edge**: If at an edge, it calls the tmux script to switch panes
3. **Cursor Awareness**: The tmux script records your cursor position and finds the best matching pane
4. **Window Selection**: When entering a Vim pane, it selects the window that best matches your previous cursor position

## Troubleshooting

### Script Not Found

If you get an error about `tmux-smart-switch-pane` not being found:

1. Check if the script exists in the plugin directory:
   ```bash
   find ~/.vim -name "tmux-smart-switch-pane" 2>/dev/null
   ```

2. Copy it to your PATH:
   ```bash
   cp /path/to/smart-tmux-nav.vim/bin/tmux-smart-switch-pane ~/.local/bin/
   chmod +x ~/.local/bin/tmux-smart-switch-pane
   ```

### Navigation Not Working

1. Ensure tmux key bindings are properly configured
2. Check that the plugin is loaded: `:echo g:loaded_smart_tmux_nav`
3. Enable debug mode to see what's happening
4. Verify tmux version: `tmux -V` (should be >= 2.0)

## API

### Mappings

The plugin provides the following `<Plug>` mappings:

- `<Plug>SmartTmuxNavLeft` - Navigate left
- `<Plug>SmartTmuxNavDown` - Navigate down
- `<Plug>SmartTmuxNavUp` - Navigate up
- `<Plug>SmartTmuxNavRight` - Navigate right

### Functions

- `smart_tmux_nav#navigate(direction)` - Navigate in the given direction ('h', 'j', 'k', 'l')

### Variables

- `g:smart_tmux_nav_debug` - Enable debug logging (default: 0)

## License

MIT