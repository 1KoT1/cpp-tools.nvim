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

return M
