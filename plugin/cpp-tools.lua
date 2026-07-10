-- cpp-tools.nvim
-- Plugin loader — ensures the plugin is loaded after Vim's startup

if vim.g.did_load_cpp_tools then
	return
end
vim.g.did_load_cpp_tools = true
