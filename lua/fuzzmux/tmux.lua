local M = {}

-- Is this running inside tmux?
function M.is_tmux()
  return os.getenv("TMUX_PANE") ~= nil
end

-- Cache var names to avoid repeated tmux queries
local _cached_current_file_var = nil
local _cached_open_files_var = nil
local _cached_nvim_socket_var = nil

local function get_var_names()
  if _cached_current_file_var and _cached_open_files_var and _cached_nvim_socket_var then
    return _cached_current_file_var, _cached_open_files_var, _cached_nvim_socket_var
  end

  local pane_id = os.getenv("TMUX_PANE")

  _cached_current_file_var = string.format("FUZZMUX_CURRENT_FILE_%s", pane_id)
  _cached_open_files_var = string.format("FUZZMUX_OPEN_FILES_%s", pane_id)
  _cached_nvim_socket_var = string.format("FUZZMUX_NVIM_SOCKET_%s", pane_id)

  return _cached_current_file_var, _cached_open_files_var, _cached_nvim_socket_var
end

local function clear_var_cache()
  _cached_current_file_var = nil
  _cached_open_files_var = nil
  _cached_nvim_socket_var = nil
end

-- Set Neovim server socket address variable in tmux
function M.set_nvim_socket()
  -- current Neovim server socket
  local nvim_socket = vim.v.servername
  if not nvim_socket then
    return
  end

  -- pane-specific global variable name
  local _, _, nvim_socket_var_name = get_var_names()

  if vim.system then
    vim.system(
      { "tmux", "set-environment", "-g", nvim_socket_var_name, vim.fn.shellescape(nvim_socket) },
      { detach = true }
    )
  else
    vim.fn.system(
      string.format(
        "tmux set-environment -g %s %s >/dev/null 2>&1",
        nvim_socket_var_name,
        vim.fn.shellescape(nvim_socket)
      )
    )
  end
end

-- Neovim Lua: set pane-specific FUZZMUX_CURRENT_FILE in tmux
function M.set_current_file()
  -- current buffer full path
  local fname = vim.fn.expand("%:p")

  -- pane-specific global variable name
  local current_file_var_name = get_var_names()
  -- if not inside tmux, exit
  if not current_file_var_name then
    return
  end

  -- set global tmux env variable
  if vim.system then
    vim.system({ "tmux", "set-environment", "-g", current_file_var_name, vim.fn.shellescape(fname) }, { detach = true })
  else
    vim.fn.system(
      string.format("tmux set-environment -g %s %s >/dev/null 2>&1", current_file_var_name, vim.fn.shellescape(fname))
    )
  end
end

function M.set_open_files()
  vim.schedule(function()
    local _, open_files_var_name = get_var_names()
    if not open_files_var_name then
      return
    end

    -- get all listed buffers with file paths
    local buffers = {}
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
      -- Check if buffer is valid and listed
      if vim.api.nvim_buf_is_valid(buf) then
        local ok, is_listed = pcall(vim.api.nvim_buf_get_option, buf, "buflisted")
        if ok and is_listed then
          local bufname = vim.api.nvim_buf_get_name(buf)
          -- Include buffers with names, even if not fully loaded yet
          if bufname ~= "" and bufname:match("^/") then
            table.insert(buffers, bufname)
          end
        end
      end
    end

    -- join all buffer paths with colon separator
    local files_list = table.concat(buffers, ":")

    -- Async system call using vim.system (Neovim 0.10+) or fallback to vim.fn.system
    if vim.system then
      vim.system({ "tmux", "set-environment", "-g", open_files_var_name, files_list }, { detach = true })
    else
      vim.fn.system(
        string.format(
          "tmux set-environment -g %s %s >/dev/null 2>&1",
          open_files_var_name,
          vim.fn.shellescape(files_list)
        )
      )
    end
  end)
end

function M.unset_nvim_socket()
  local _, _, nvim_socket_var_name = get_var_names()
  if not nvim_socket_var_name then
    return
  end
  -- unset global tmux env variable
  if vim.system then
    vim.system({ "tmux", "set-environment", "-gu", nvim_socket_var_name }, { detach = true })
  else
    vim.fn.system(string.format("tmux set-environment -gu %s >/dev/null 2>&1", nvim_socket_var_name))
  end
end

function M.unset_current_file()
  -- pane-specific global variable name
  local current_file_var_name = get_var_names()
  -- if not inside tmux, exit
  if not current_file_var_name then
    return
  end

  -- unset global tmux env variable
  if vim.system then
    vim.system({ "tmux", "set-environment", "-gu", current_file_var_name }, { detach = true })
  else
    vim.fn.system(string.format("tmux set-environment -gu %s >/dev/null 2>&1", current_file_var_name))
  end
end

function M.unset_open_files()
  local _, open_files_var_name = get_var_names()
  if not open_files_var_name then
    return
  end

  -- unset global tmux env variable
  if vim.system then
    vim.system({ "tmux", "set-environment", "-gu", open_files_var_name }, { detach = true })
  else
    vim.fn.system(string.format("tmux set-environment -gu %s >/dev/null 2>&1", open_files_var_name))
  end
end

-- Refresh tmux environment variables
function M.refresh_vars()
  pcall(M.unset_current_file)
  pcall(M.unset_open_files)
  pcall(M.unset_nvim_socket)

  pcall(clear_var_cache)

  pcall(M.set_current_file)
  pcall(M.set_open_files)
  pcall(M.set_nvim_socket)
end

return M
