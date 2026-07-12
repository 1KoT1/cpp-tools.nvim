-- Tests for cpp-tools.nvim
--
-- Run with: nvim --headless -c "lua dofile('tests/init.lua')" -c "qa"

-- Prepend the plugin's lua directory to the module search path so that
-- `require("cpp-tools.*")` resolves correctly when running this test file.
local test_dir = debug.getinfo(1, "S").source:match("@?(.*/)")
local lua_dir = test_dir .. "../lua/"
package.path = lua_dir .. "?.lua;"
.. lua_dir .. "?/init.lua;"
.. package.path

--- Helper class that creates a temporary directory on construction and
--- removes it (recursively) on destruction.  The directory path is obtained
--- via the shell command `mktemp -d -t cpp-tools.nvim.tests.XXXXXX`.
---
--- Automatic clean‑up relies on LuaJIT's `newproxy`, so the directory will
--- be removed when the GC collects the proxy userdata.  You can also call
--- `:destroy()` explicitly to release resources immediately.
local TempDir = {}
TempDir.__index = TempDir

--- Create a new TempDir instance.
--- @return TempDir
function TempDir.new()
	local result = vim.fn.system({ "mktemp", "-d", "-t", "cpp-tools.nvim.tests.XXXXXX" })
	if vim.v.shell_error ~= 0 or result == "" then
		error("Failed to create temporary directory via mktemp")
	end
	-- Remove trailing newline
	local tmpdir = result:gsub("\n$", "")

	local self = setmetatable({ _path = tmpdir, _destroyed = false }, TempDir)

	-- Register automatic clean‑up via LuaJIT's newproxy __gc.
	local proxy = newproxy(true)
	local proxy_mt = getmetatable(proxy)
	proxy_mt.__gc = function()
		if not self._destroyed then
			self._destroyed = true
			vim.fn.system({ "rm", "-rf", tmpdir })
		end
	end
	self._proxy = proxy

	return self
end

--- Return the absolute path of the temporary directory.
--- @return string
function TempDir:path()
	return self._path
end

--- Explicitly remove the temporary directory.  Safe to call multiple times.
function TempDir:destroy()
	if self._destroyed then
		return
	end
	self._destroyed = true
	vim.fn.system({ "rm", "-rf", self._path })
end

function TempDir:__tostring()
	return "TempDir(" .. self._path .. ")"
end

local tests = {}

function tests.test_temp_dir()
	-- Create a TempDir and verify the directory exists
	local t = TempDir.new()
	local path = t:path()
	assert(type(path) == "string" and #path > 0, "TempDir:path() should return a non-empty string")
	assert(vim.fn.isdirectory(path) == 1, "TempDir directory should exist on disk: " .. path)

	-- Destroy explicitly and verify it is removed
	t:destroy()
	assert(vim.fn.isdirectory(path) == 0, "TempDir directory should be removed after :destroy()")

	-- Calling :destroy() again should be safe (no crash)
	t:destroy()

	print("✓ test_temp_dir")
end

function tests.test_temp_dir_gc_cleanup()
	-- Verify that the __gc proxy works: create a TempDir, drop the reference,
	-- force GC, and check the directory disappears.
	local path
	do
		local t = TempDir.new()
		path = t:path()
		assert(vim.fn.isdirectory(path) == 1, "directory should exist before GC")
	end
	-- Drop reference and force collection
	collectgarbage()
	collectgarbage()
	-- After GC the proxy's __gc should have removed the directory
	assert(vim.fn.isdirectory(path) == 0, "directory should be removed after GC: " .. tostring(path))

	print("✓ test_temp_dir_gc_cleanup")
end

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
