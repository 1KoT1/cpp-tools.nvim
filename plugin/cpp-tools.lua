-- cpp-tools.nvim
-- Plugin loader — ensures the plugin is loaded after Vim's startup

if vim.g.did_load_cpp_tools then
  return
end
vim.g.did_load_cpp_tools = true

-- Defer loading until VimEnter to not interfere with other plugins
vim.api.nvim_create_autocmd("User", {
  pattern = "VeryLazy",
  callback = function()
    require("cpp-tools").setup()
  end,
})
