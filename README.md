# fuzzmux.nvim

Created to solve the workflow of managing multiple Neovim instances across tmux panes with fuzzy finding.

A Neovim plugin that tracks your open buffers and current file in tmux environment variables. **Needs** [fuzzmux.tmux](https://github.com/pteroctopus/fuzzmux.tmux) to enable fuzzy finding and switching between Neovim buffers across different tmux panes.

## Features

- **Automatic buffer tracking** - Tracks all open buffers and syncs to tmux
- **Current file tracking** - Keeps track of the active buffer
- **Auto cleanup** - Removes environment variables when Neovim exits
- **Pane-specific** - Each tmux pane has its own tracked buffers
- **Zero configuration** - Works out of the box
- **Neovim 0.10+** - Uses async APIs when available

https://github.com/user-attachments/assets/4aea9c2f-5e3a-4e61-850a-e3ad7f1937b4

## Requirements

- [fuzzmux.tmux](https://github.com/pteroctopus/fuzzmux.tmux) for the fuzzy finder interface
- **Neovim** >= 0.10.0
- **tmux** >= 3.2
- Running Neovim inside a tmux session

## Installation

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  'pteroctopus/fuzzmux.nvim',
  opts = {
    -- Optional configuration
    -- Currently no options available
    -- This is a placeholder for future configuration
  },
}
```

## Usage

Once installed, fuzzmux.nvim works automatically in the background.

### Viewing the Environment Variables

You can check the environment variables set by fuzzmux.nvim:

```bash
# From your shell inside tmux
tmux show-environment -g | grep FUZZMUX_

# Or from Neovim command line
:!tmux show-environment -g | grep FUZZMUX_
```

### Integration with fuzzmux.tmux

Install [fuzzmux.tmux](https://github.com/pteroctopus/fuzzmux.tmux) to get fuzzy finding capabilities:

```bash
# With TPM - add to ~/.tmux.conf
set -g @plugin 'pteroctopus/fuzzmux.tmux'
```

Then use the buffer switcher:
- `prefix` + <kbd>f</kbd> - Open fuzzy finder for Neovim buffers
- `prefix` + <kbd>F</kbd> - Open fuzzy finder with zoom

Fuzzmux offers more keybindings. Check the [fuzzmux.tmux README](https://www.github.com/pteroctopus/fuzzmux.tmux)

**Normal (without zoom):**
- `prefix` + <kbd>s</kbd> - Fuzzy find and switch to a session
- `prefix` + <kbd>p</kbd> - Fuzzy find and switch to a pane
- `prefix` + <kbd>w</kbd> - Fuzzy find and switch to a window
- `prefix` + <kbd>f</kbd> - Fuzzy find and switch to a Neovim buffer

**With zoom (uppercase keys):**
- `prefix` + <kbd>S</kbd> - Fuzzy find and switch to a session (with zoom)
- `prefix` + <kbd>P</kbd> - Fuzzy find and switch to a pane (with zoom)
- `prefix` + <kbd>W</kbd> - Fuzzy find and switch to a window (with zoom)
- `prefix` + <kbd>F</kbd> - Fuzzy find and switch to a Neovim buffer (with zoom)

## Technical Details

### How It Works

fuzzmux.nvim sets tmux global environment variables that contain information about your Neovim buffers:

```bash
# List of all open buffers in a specific pane (colon-separated)
FUZZMUX_OPEN_FILES_<pane_id>="/path/to/file1.txt:/path/to/file2.lua:/path/to/file3.md"

# Currently active buffer in a specific pane
FUZZMUX_CURRENT_FILE_<pane_id>="/path/to/current/file.lua"

# Neovim socket path for a specific pane
FUZZMUX_NVIM_SOCKET_<pane_id>="/path/to/nvim/socket"
```

These variables are automatically updated when you:
- Open a new buffer
- Close a buffer
- Switch between buffers
- Start or exit Neovim

The [fuzzmux.tmux](https://github.com/pteroctopus/fuzzmux.tmux) plugin reads these variables to provide fuzzy finding capabilities.


### Autocommands

fuzzmux.nvim creates autocommands for the following events:

| Event         |
|---------------|
| `BufEnter`    |
| `VimEnter`    |
| `BufAdd`      |
| `BufDelete`   |
| `VimLeavePre` |

### Performance Optimizations

- **Caching**: Session, window, and pane identifiers are cached on first query
- **Async operations**: Uses `vim.system()` (Neovim 0.10+) for non-blocking tmux calls
- **Fallback**: Falls back to `vim.fn.system()` for older Neovim versions
- **Selective updates**: Only tracks listed buffers with valid file paths

### Buffer Filtering

The plugin only tracks buffers that:
- Are valid (`nvim_buf_is_valid`)
- Are listed (`buflisted` option is true)
- Have a non-empty name
- Have an absolute path (starts with `/`)

This excludes:
- Unlisted buffers
- Terminal buffers without files
- Special buffers (like `[Command Line]`)
- Relative paths

### Environment Variable Names

The plugin uses a consistent naming convention with fuzzmux.tmux:

```bash
FUZZMUX_OPEN_FILES_<pane_id>
FUZZMUX_CURRENT_FILE_<pane_id>
```

## Troubleshooting

### No environment variables are set

**Check if Neovim is running inside tmux:**

```lua
:lua print(os.getenv("TMUX_PANE"))
```

If this returns `nil`, you're not in a tmux session. fuzzmux.nvim only works inside tmux.

**Check if the plugin is loaded:**

```lua
:lua print(vim.g.loaded_fuzzmux_nvim)
```

Should return `1`. If it returns `nil`, the plugin isn't loaded.

### Environment variables not updating

**Check for errors in Neovim:**

```vim
:messages
```

**Manually trigger an update:**

```lua
:lua require('fuzzmux.tmux').set_open_files()
:lua require('fuzzmux.tmux').set_current_file()
```

### Variables not cleaning up on exit

This is expected behavior if Neovim crashes or is force-killed. Normally, the `VimLeavePre` autocommand handles cleanup. Stale variables don't cause issues and will be overwritten on next launch.

## API

While fuzzmux.nvim is designed to work automatically, you can access its functions programmatically:

```lua
local tmux = require('fuzzmux.tmux')

-- Check if running in tmux
if tmux.is_tmux() then
  -- Manually update current file
  tmux.set_current_file()
  
  -- Manually update open files list
  tmux.set_open_files()
  
  -- Clean up current file variable
  tmux.unset_current_file()
  
  -- Clean up open files variable
  tmux.unset_open_files()
end
```

## Why fuzzmux?

### The Problem

When working with tmux and Neovim:
- You have multiple tmux panes, each running different Neovim instances
- Each Neovim instance has multiple buffers open
- Switching to a specific file across panes requires:
  1. Finding which pane has the Neovim instance
  2. Switching to that pane
  3. Switching to the correct buffer

### The Solution

fuzzmux provides:
- **One keybinding** to see all files open in all Neovim instances
- **Fuzzy search** to quickly find the file you want
- **Automatic switching** to the correct pane and buffer
- **Live preview** of file contents before switching

## Related Projects

- [fuzzmux.tmux](https://github.com/pteroctopus/fuzzmux.tmux) - tmux plugin with fuzzy finder interface
- [fzf](https://github.com/junegunn/fzf) - Command-line fuzzy finder
- [tmux](https://github.com/tmux/tmux) - Terminal multiplexer

