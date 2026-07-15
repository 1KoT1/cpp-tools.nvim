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

function M.wrap_error(action, massage)
	local ok, r1, r2, r3, r4, r5, r6, r7, r8, r9, r10 = xpcall(action, debug.traceback)
	if ok then
		return r1, r2, r3, r4, r5, r6, r7, r8, r9, r10
	else
		error(message..' -- '..r1)
	end
end

return M
