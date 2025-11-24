local tmux = require("fuzzmux.tmux")

-- Configuration for fuzzmux.nvim
-- Currently no configuration is needed, but this is a placeholder for future options.
local M = {}

local defaults = {}

M.opts = defaults

function M.setup(user_opts)
  M.opts = vim.tbl_extend("force", defaults, user_opts or {})
end

-- Check if Neovim is running inside tmux. If not don't set up autocommands.
if not tmux.is_tmux() then
  return M
end

-- Create an augroup for fuzzmux autocommands
local augroup_id = vim.api.nvim_create_augroup("FuzzmuxNvimFiles", { clear = true })

vim.api.nvim_create_autocmd({ "VimEnter" }, {
  callback = function()
    tmux.set_current_file()
    tmux.set_open_files()
    tmux.set_nvim_socket()
  end,
  desc = "[fuzzmux.nvim] Set initial FUZZMUX tmux environment variables on VimEnter",
  group = augroup_id,
})

-- Create autocommands to update tmux environment variables on relevant events
vim.api.nvim_create_autocmd({ "BufEnter" }, {
  callback = function()
    tmux.set_current_file()
  end,
  desc = "[fuzzmux.nvim] Set FUZZMUX_CURRENT_FILE when switching buffers",
  group = augroup_id,
})

vim.api.nvim_create_autocmd({ "BufAdd", "BufDelete" }, {
  callback = tmux.set_open_files,
  desc = "[fuzzmux.nvim] Update FUZZMUX_OPEN_FILES when buffers change",
  group = augroup_id,
})

vim.api.nvim_create_autocmd({ "VimLeavePre" }, {
  callback = function()
    tmux.unset_current_file()
    tmux.unset_open_files()
    tmux.unset_nvim_socket()
  end,
  desc = "[fuzzmux.nvim] Unset FUZZMUX tmux environment variables on VimLeave",
  group = augroup_id,
})

return M
