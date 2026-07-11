-- cpp-tools.nvim
-- Utility functions

local M = {}

--- Check if the current buffer is a C/C++ file
--- @return boolean
function M.is_cpp_buffer()
	local ft = vim.bo.filetype
	local cpp_filetypes = { "cpp", "c", "h", "hpp" }
	return vim.tbl_contains(cpp_filetypes, ft)
end

--- Get the project root directory (heuristic: .git, CMakeLists.txt, etc.)
--- @return string|nil
function M.get_project_root()
	local markers = { ".git", "CMakeLists.txt", "Makefile", ".clangd" }
	local root = vim.fs.root(0, markers)
	return root
end

return M
