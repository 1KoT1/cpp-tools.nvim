-- Tests for cpp-tools.nvim add-gtest tool
--
-- Run with: nvim --cmd "set rtp+=`pwd`" --headless -c "lua dofile('tests/init.lua')" -c "qa"

-- Prepend the plugin's lua directory to the module search path so that
-- `require("cpp-tools.*")` resolves correctly when running this test file.
local test_dir = debug.getinfo(1, "S").source:match("@?(.*/)")
local lua_dir = test_dir .. "../lua/"
package.path = lua_dir .. "?.lua;"
.. lua_dir .. "?/init.lua;"
.. package.path

-- Load shared test helpers (with_tmp_dir, etc.)
with_tmp_dir = dofile(test_dir .. "helpers.lua")

local tests = {}

function tests.test_add_gtest_module_name_parsing()
	-- ── Environment preparation ──
	local add_gtest = require("cpp-tools.tools.add-gtest")

	-- ── Test scenario execution ──
	-- We can't easily call the full run() in a unit test since it requires
	-- user input and cursor context; so we test the helper functions via
	-- the module's implementation details by checking the effects.

	-- Instead, test the class detector module separately and the content
	-- generation from defaults.

	-- Verify that the add_gtest module loads without error
	assert(add_gtest ~= nil, "add-gtest module should load")
	assert(type(add_gtest.run) == "function", "add-gtest should have run() function")
end

function tests.test_add_gtest_default_content_generation()
	-- ── Environment preparation ──
	local defaults = require("cpp-tools.defaults")

	-- ── Test scenario execution ──
	with_tmp_dir(function(tmpdir)
		local test_path = tmpdir .. "/MyClassTests.cpp"

		defaults.add_gtest.fill_test_content(
			"ns1/ns2/MyClass.h",
			{ "ns1", "ns2" },
			"MyClassTests",
			test_path
		)

		-- ── Result verification ──
		assert(
			vim.fn.filereadable(test_path) == 1,
			"Test file should exist: " .. test_path
		)

		local lines = vim.fn.readfile(test_path)
		assert(#lines > 0, "Test file should not be empty")

		-- Check #include of class header
		local has_header_include = false
		local has_gtest_include = false
		local has_test_macro = false
		local has_namespace_open = false
		local has_namespace_close = false

		for _, line in ipairs(lines) do
			if line == '#include "ns1/ns2/MyClass.h"' then
				has_header_include = true
			end
			if line == '#include <gtest/gtest.h>' then
				has_gtest_include = true
			end
			if line:match("^TEST%(MyClassTests%, Test1%)") then
				has_test_macro = true
			end
			if line == "namespace ns1 {" then
				has_namespace_open = true
			end
			if line == "}  // namespace ns2" or line:match("}%s+//%s+namespace%s+ns2") then
				has_namespace_close = true
			end
		end

		assert(has_header_include, "Test file should #include the class header")
		assert(has_gtest_include, "Test file should #include <gtest/gtest.h>")
		assert(has_test_macro, "Test file should contain TEST() macro")
		assert(has_namespace_open, "Test file should open namespace ns1")
		assert(has_namespace_close, "Test file should close namespace ns2")
	end)
end

function tests.test_add_gtest_content_without_namespaces()
	-- ── Environment preparation ──
	local defaults = require("cpp-tools.defaults")

	-- ── Test scenario execution ──
	with_tmp_dir(function(tmpdir)
		local test_path = tmpdir .. "/SimpleTests.cpp"

		defaults.add_gtest.fill_test_content(
			"MyClass.h",
			{},
			"SimpleTests",
			test_path
		)

		-- ── Result verification ──
		local lines = vim.fn.readfile(test_path)
		assert(#lines > 0, "Test file should not be empty")

		-- Should have no namespace blocks
		local has_namespace = false
		for _, line in ipairs(lines) do
			if line:match("^namespace ") then
				has_namespace = true
			end
		end
		assert(not has_namespace, "Test without namespaces should not contain namespace blocks")

		-- Should still have the TEST macro
		local has_test = false
		for _, line in ipairs(lines) do
			if line:match("^TEST%(") then
				has_test = true
				break
			end
		end
		assert(has_test, "Test file should contain TEST() macro even without namespaces")
	end)
end

function tests.test_class_detector_loads()
	-- ── Test scenario execution ──
	local class_detector = require("cpp-tools.tools.class-detector")

	-- ── Result verification ──
	assert(class_detector ~= nil, "class-detector module should load")
	assert(type(class_detector.detect) == "function", "class-detector should have detect() function")
end

return tests
