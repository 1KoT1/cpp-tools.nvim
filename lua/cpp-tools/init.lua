-- cpp-tools.nvim
-- Main entry point for the plugin
--
-- Collection of tools for coding on C++ in Neovim

local M = {}

-- Import modules
M.config = require("cpp-tools.config")
M.tools = require("cpp-tools.tools")
M.utils = require("cpp-tools.utils")

--- Setup the plugin with user configuration
--- @param opts table|nil User configuration options
function M.setup(opts)
  M.config.setup(opts)
end

return M
