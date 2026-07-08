-- Tests for cpp-tools.nvim
--
-- Run with: nvim --headless -c "lua dofile('tests/init.lua')" -c "qa"

local tests = {}

function tests.test_config_defaults()
  local config = require("cpp-tools.config")
  config.setup({})
  assert(config.options.debug == false, "debug should default to false")
  assert(type(config.options.filetypes) == "table", "filetypes should be a table")
  assert(config.options.prefix == "<leader>c", "prefix should default to <leader>c")
  print("✓ test_config_defaults")
end

function tests.test_config_custom()
  local config = require("cpp-tools.config")
  config.setup({ debug = true })
  assert(config.options.debug == true, "debug should be true")
  print("✓ test_config_custom")
end

function tests.test_is_cpp_buffer()
  local utils = require("cpp-tools.utils")
  -- Mock filetype check would go here in a real test environment
  print("✓ test_is_cpp_buffer (structure OK)")
end

-- Run tests
print("Running cpp-tools.nvim tests...")
for name, fn in pairs(tests) do
  local ok, err = pcall(fn)
  if not ok then
    print("✗ " .. name .. ": " .. tostring(err))
  end
end
print("Done.")
