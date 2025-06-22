#!/bin/bash
# Installation script for smart-tmux-nav.nvim tmux components

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_NAME="tmux-smart-switch-pane"
SOURCE_FILE="$SCRIPT_DIR/bin/$SCRIPT_NAME"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo "smart-tmux-nav.nvim installer"
echo "=============================="
echo

# Check if script exists
if [ ! -f "$SOURCE_FILE" ]; then
    echo -e "${RED}Error: $SCRIPT_NAME not found at $SOURCE_FILE${NC}"
    exit 1
fi

# Determine installation directory
if [ -d "$HOME/.local/bin" ]; then
    INSTALL_DIR="$HOME/.local/bin"
elif [ -d "$HOME/bin" ]; then
    INSTALL_DIR="$HOME/bin"
else
    echo -e "${YELLOW}No ~/.local/bin or ~/bin directory found.${NC}"
    echo "Creating ~/.local/bin..."
    mkdir -p "$HOME/.local/bin"
    INSTALL_DIR="$HOME/.local/bin"
    echo -e "${YELLOW}Remember to add ~/.local/bin to your PATH${NC}"
fi

DEST_FILE="$INSTALL_DIR/$SCRIPT_NAME"

# Install the script
echo "Installing $SCRIPT_NAME to $INSTALL_DIR..."
cp "$SOURCE_FILE" "$DEST_FILE"
chmod +x "$DEST_FILE"

echo -e "${GREEN}✓ Installation complete!${NC}"
echo

# Check if directory is in PATH
if ! echo "$PATH" | grep -q "$INSTALL_DIR"; then
    echo -e "${YELLOW}Warning: $INSTALL_DIR is not in your PATH${NC}"
    echo "Add this to your shell configuration file:"
    echo
    echo "  export PATH=\"\$PATH:$INSTALL_DIR\""
    echo
fi

# Display tmux configuration
echo "Now add the following to your ~/.tmux.conf:"
echo
cat << 'EOF'
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
EOF

echo
echo "Don't forget to reload tmux configuration:"
echo "  tmux source-file ~/.tmux.conf"
echo
echo -e "${GREEN}Done!${NC}"