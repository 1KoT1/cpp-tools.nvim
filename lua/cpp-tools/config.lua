-- cpp-tools.nvim
-- Configuration module with default settings

local M = {}

--- Default plugin configuration
local defaults = {
	--- Enable debugging output
	debug = false,

	--- Filetypes that the plugin activates for
	filetypes = { "cpp", "c", "h", "hpp" },
}

--- Current merged configuration
M.options = {}

--- Setup configuration, merging user options with defaults
--- @param opts table|nil User configuration options
function M.setup(opts)
	M.options = vim.tbl_deep_extend("keep", opts or {}, defaults)
end

--- Get the current configuration
--- @return table
function M.get()
	return M.options
end

return M
