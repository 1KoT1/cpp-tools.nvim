-- cpp-tools.nvim
-- Tools module — a collection of C++ development tools

local M = {}

--- Setup all tools and register commands/keymaps
function M.setup(opts)
	-- Register :CppCreateClass command
	vim.api.nvim_create_user_command("CppCreateClass", function()
		require("cpp-tools.tools.create-class").run()
	end, {})

	-- Register :CppAddGTest command
	vim.api.nvim_create_user_command("CppAddGTest", function()
		require("cpp-tools.tools.add-gtest").run()
	end, {})
end

return M
