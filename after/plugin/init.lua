if vim.g.loaded_fuzzmux_nvim == 1 then
  return
end
vim.g.loaded_fuzzmux_nvim = 1

require("fuzzmux").setup()
