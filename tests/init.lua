-- Tests for cpp-tools.nvim
--
-- Run with: nvim --cmd "set rtp+=`pwd`" --headless -c "lua dofile('tests/init.lua')" -c "qa"

-- Prepend the plugin's lua directory to the module search path so that
-- `require("cpp-tools.*")` resolves correctly when running this test file.
local test_dir = debug.getinfo(1, "S").source:match("@?(.*/)")
local lua_dir = test_dir .. "../lua/"
package.path = lua_dir .. "?.lua;"
.. lua_dir .. "?/init.lua;"
.. package.path

-- Load shared test helpers (TempDir, etc.)
TempDir = dofile(test_dir .. "helpers.lua")

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
end

function tests.test_config_defaults()
	local config = require("cpp-tools.config")
	config.setup({})
	assert(config.options.debug == false, "debug should default to false")
	assert(type(config.options.filetypes) == "table", "filetypes should be a table")
end

function tests.test_config_defaults_with_one_replace()
	-- Use a fresh config module for isolation
	local config = require("cpp-tools.config")

	-- Setup with one replace
	config.setup({
		customisations = {
			header_relative_path_fn =
			function(namespaces, class_name)
				return "custom/" .. (#namespaces > 0 and table.concat(namespaces, '/') .. '/' or "") .. class_name .. ".hpp"
			end
		},
	})

	-- ── Check that all other settings remain at their defaults ──
	local defaults_f = require("cpp-tools.defaults")

	-- Top-level fields
	assert(config.options.debug == false, "debug should default to false")
	assert(type(config.options.filetypes) == "table", "filetypes should be a table")

	-- Other customisations functions (must still be the default implementations)
	assert(
		config.options.customisations.headers_dir_fn == defaults_f.headers_dir,
		"headers_dir_fn should be the default function"
	)
	assert(
		config.options.customisations.source_relative_path_fn == defaults_f.source_relative_path,
		"source_relative_path_fn should be the default function"
	)
	assert(
		config.options.customisations.sources_dir_fn == defaults_f.sources_dir,
		"sources_dir_fn should be the default function"
	)
	assert(
		config.options.customisations.create_class.fill_header_content_fn == defaults_f.create_class.fill_header_content,
		"fill_header_content_fn should be the default function"
	)
	assert(
		config.options.customisations.create_class.fill_source_content_fn == defaults_f.create_class.fill_source_content,
		"fill_source_content_fn should be the default function"
	)
end


function tests.test_config_custom()
	local config = require("cpp-tools.config")
	config.setup({ debug = true })
	assert(config.options.debug == true, "debug should be true")
end

function tests.test_customisations_header_relative_path_fn()
	-- Use a fresh config module for isolation
	local config = require("cpp-tools.config")

	-- Build a custom header_relative_path_fn
	local custom_fn = function(namespaces, class_name)
		return "custom/" .. (#namespaces > 0 and table.concat(namespaces, '/') .. '/' or "") .. class_name .. ".hpp"
	end

	-- Setup with only header_relative_path_fn overridden
	config.setup({
		customisations = {
			header_relative_path_fn = custom_fn,
		},
	})

	-- ── Check that header_relative_path_fn is our custom function ──
	assert(
		config.options.customisations.header_relative_path_fn == custom_fn,
		"header_relative_path_fn should be the custom function"
	)

	-- Verify it works as expected
	local rel = config.options.customisations.header_relative_path_fn({ "ns1", "ns2" }, "MyClass")
	assert(rel == "custom/ns1/ns2/MyClass.hpp", "custom function should produce 'custom/ns1/ns2/MyClass.hpp', got: " .. tostring(rel))
end

-- Load create class tests
local create_class_tests = dofile(test_dir .. "create_class_spec.lua")
for name, fn in pairs(create_class_tests) do
	tests[name] = fn
end

-- Run tests
local failed_tests = {}
print("Running cpp-tools.nvim tests...")
for name, fn in pairs(tests) do
	local ok, err = pcall(fn)
	if ok then
		print("✓ "..name)
	else
		failed_tests[#failed_tests] = msg
		print(msg)
	end
end
print("Done.")
if #failed_tests == 0 then
	print("============")
	print("Success")
else
	print("============")
	print("Failed tests")
	for _, msg in pairs(failed_tests) do
		print(msg)
	end
end
print("")
