-- cpp-tools.nvim
-- Tools module — a collection of C++ development tools

local M = {}

--- Setup all tools and register commands/keymaps
function M.setup(opts)
  -- TODO: Register tools here
  --
  -- Example tools to implement:
  --   - Class/header generation
  --   - Switch between source/header
  --   - Insert standard boilerplate (include guards, etc.)
  --   - Run clang-format / clang-tidy integration
  --   - CMake integration helpers
  vim.notify("cpp-tools.nvim: tools loaded", vim.log.levels.INFO)
end

return M
