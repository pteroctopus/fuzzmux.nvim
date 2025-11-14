local M = {}

-- Is this running inside tmux?
function M.is_tmux()
  return os.getenv("TMUX_PANE") ~= nil
end

-- Cache var names to avoid repeated tmux queries
local cached_var_name = nil
local cached_open_files_var = nil

local function get_var_name()
  if cached_var_name then return cached_var_name end

  -- Single tmux call to get all info at once
  local info = vim.fn.system("tmux display-message -p '#{session_name} #{window_index} #{pane_index}'"):gsub("%s+$", "")
  local session, window, pane_index = info:match("^(%S+)%s+(%S+)%s+(%S+)")

  if not session or not window or not pane_index then return end

  cached_var_name = string.format("FUZZMUX_CURRENT_FILE_%s_%s_%s", session, window, pane_index)
  cached_open_files_var = string.format("FUZZMUX_OPEN_FILES_%s_%s_%s", session, window, pane_index)

  return cached_var_name
end


-- Neovim Lua: set pane-specific FUZZMUX_CURRENT_FILE in tmux
function M.set_current_file()
  -- current buffer full path
  local fname = vim.fn.expand('%:p')

  -- pane-specific global variable name
  local var_name = get_var_name()
  -- if not inside tmux, exit
  if not var_name then return end

  -- set global tmux env variable
  if vim.system then
    vim.system({"tmux", "set-environment", "-g", var_name, vim.fn.shellescape(fname)}, {detach = true})
  else
    vim.fn.system(string.format(
      "tmux set-environment -g %s %s >/dev/null 2>&1",
      var_name,
      vim.fn.shellescape(fname)
    ))
  end
end

-- Debounce timer for open files updates
local update_timer = nil

function M.set_open_files()
  if update_timer then
    update_timer:stop()
  end

    local var_name = get_var_name()
    if not var_name then return end

    -- get all listed buffers with file paths
    local buffers = {}
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
      -- Check if buffer is valid and listed
      if vim.api.nvim_buf_is_valid(buf) then
        local ok, is_listed = pcall(vim.api.nvim_buf_get_option, buf, 'buflisted')
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
      vim.system({"tmux", "set-environment", "-g", cached_open_files_var, files_list}, {detach = true})
    else
      vim.fn.system(string.format(
        "tmux set-environment -g %s %s >/dev/null 2>&1",
        cached_open_files_var,
        vim.fn.shellescape(files_list)
      ))
    end
end

function M.unset_current_file()
  -- pane-specific global variable name
  local var_name = get_var_name()
  -- if not inside tmux, exit
  if not var_name then return end

  -- unset global tmux env variable
  if vim.system then
    vim.system({"tmux", "set-environment", "-gu", var_name}, {detach = true})
  else
    vim.fn.system(string.format(
      "tmux set-environment -gu %s >/dev/null 2>&1",
      var_name
    ))
  end
end

function M.unset_open_files()
  if not cached_open_files_var then return end

  -- unset global tmux env variable
  if vim.system then
    vim.system({"tmux", "set-environment", "-gu", cached_open_files_var}, {detach = true})
  else
    vim.fn.system(string.format(
      "tmux set-environment -gu %s >/dev/null 2>&1",
      cached_open_files_var
    ))
  end
end

return M
