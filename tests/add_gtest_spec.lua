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

function tests.test_default_test_path()
	-- ── Environment preparation ──
	local defaults = require("cpp-tools.defaults")

	-- ── Test scenario execution ──
	local path = defaults.test_path("/project", { "ns1", "ns2" }, "MyClassTests")

	-- ── Result verification ──
	assert(
		path == "/project/tests/ns1/ns2/MyClassTests.cpp",
		"test_path should produce '/project/tests/ns1/ns2/MyClassTests.cpp', got: " .. tostring(path)
	)
end

function tests.test_default_test_path_without_namespaces()
	-- ── Environment preparation ──
	local defaults = require("cpp-tools.defaults")

	-- ── Test scenario execution ──
	local path = defaults.test_path("/project", {}, "SimpleTests")

	-- ── Result verification ──
	assert(
		path == "/project/tests/SimpleTests.cpp",
		"test_path without namespaces should produce '/project/tests/SimpleTests.cpp', got: " .. tostring(path)
	)
end

function tests.test_customisation_test_path_fn_in_config()
	-- ── Environment preparation ──
	-- Use a fresh config module for isolation
	local config = require("cpp-tools.config")

	local custom_fn = function(project_root, namespaces, module_name)
		return project_root .. "/custom-test/" .. (#namespaces > 0 and table.concat(namespaces, '/') .. '/' or "") .. module_name .. ".cpp"
	end

	-- ── Test scenario execution ──
	config.setup({
		customisations = {
			test_path_fn = custom_fn,
		},
	})

	-- ── Result verification ──
	assert(
		config.options.customisations.test_path_fn == custom_fn,
		"test_path_fn should be the custom function"
	)

	-- Verify it works as expected
	local path = config.options.customisations.test_path_fn("/project", { "ns1", "ns2" }, "MyClassTests")
	assert(
		path == "/project/custom-test/ns1/ns2/MyClassTests.cpp",
		"custom function should produce '/project/custom-test/ns1/ns2/MyClassTests.cpp', got: " .. tostring(path)
	)
end

function tests.test_customisation_test_path_fn_preserves_other_defaults()
	-- ── Environment preparation ──
	local config = require("cpp-tools.config")
	local defaults_f = require("cpp-tools.defaults")

	-- ── Test scenario execution ──
	config.setup({
		customisations = {
			test_path_fn = function(project_root, namespaces, module_name)
				return project_root .. "/custom/" .. module_name .. ".cpp"
			end,
		},
	})

	-- ── Result verification ──
	-- Other customisations must still be the default implementations
	assert(
		config.options.customisations.source_path_fn == defaults_f.source_path,
		"source_path_fn should still be the default function when test_path_fn is overridden"
	)
	assert(
		config.options.customisations.headers_dir_fn == defaults_f.headers_dir,
		"headers_dir_fn should still be the default function when test_path_fn is overridden"
	)
end

function tests.test_default_prompt_module_name_exists()
	-- ── Environment preparation ──
	local defaults = require("cpp-tools.defaults")

	-- ── Test scenario execution ──
	local prompt_fn = defaults.add_gtest.prompt_module_name

	-- ── Result verification ──
	assert(
		type(prompt_fn) == "function",
		"defaults.add_gtest.prompt_module_name should be a function"
	)
end

function tests.test_customisation_prompt_module_name_fn_in_config()
	-- ── Environment preparation ──
	local config = require("cpp-tools.config")

	local captured_default = nil
	local custom_fn = function(default_value)
		captured_default = default_value
		return "custom::TestModule"
	end

	-- ── Test scenario execution ──
	config.setup({
		customisations = {
			add_gtest = {
				prompt_module_name_fn = custom_fn,
			},
		},
	})

	-- ── Result verification ──
	assert(
		config.options.customisations.add_gtest.prompt_module_name_fn == custom_fn,
		"prompt_module_name_fn should be the custom function"
	)

	-- Verify it gets called with the default value and returns expected result
	local result = config.options.customisations.add_gtest.prompt_module_name_fn("ns1::ns2::MyClassTests")
	assert(
		result == "custom::TestModule",
		"custom prompt_module_name_fn should return 'custom::TestModule', got: " .. tostring(result)
	)
	assert(
		captured_default == "ns1::ns2::MyClassTests",
		"custom prompt_module_name_fn should be called with default value 'ns1::ns2::MyClassTests', got: " .. tostring(captured_default)
	)
end

function tests.test_customisation_prompt_preserves_other_defaults()
	-- ── Environment preparation ──
	local config = require("cpp-tools.config")
	local defaults_f = require("cpp-tools.defaults")

	-- ── Test scenario execution ──
	config.setup({
		customisations = {
			add_gtest = {
				prompt_module_name_fn = function(default_value)
					return "Custom::Test"
				end,
			},
		},
	})

	-- ── Result verification ──
	-- fill_test_content_fn must still be the default implementation
	assert(
		config.options.customisations.add_gtest.fill_test_content_fn == defaults_f.add_gtest.fill_test_content,
		"fill_test_content_fn should still be the default when prompt_module_name_fn is overridden"
	)
end

function tests.test_class_detector_loads()
	-- ── Test scenario execution ──
	local class_detector = require("cpp-tools.tools.class-detector")

	-- ── Result verification ──
	assert(class_detector ~= nil, "class-detector module should load")
	assert(type(class_detector.detect) == "function", "class-detector should have detect() function")
end


-- ─────────────────────────────────────────────────────────────────────────
-- Tests for M.run() — the full add-gtest workflow
-- ─────────────────────────────────────────────────────────────────────────

--- Helper: create a scratch C++ buffer with content, set filetype=cpp.
local function create_cpp_buffer(lines)
	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_set_current_buf(buf)
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.bo[buf].filetype = "cpp"
	pcall(vim.treesitter.get_parser, buf, "cpp")
	return buf
end

function tests.test_add_gtest_run_basic_scenario()
	-- ── Environment preparation ──
	with_tmp_dir(function(tmpdir)
		local project_root = tmpdir
		vim.fn.mkdir(project_root .. "/.git", "p")
		vim.fn.chdir(project_root)

		-- Create a C++ buffer with a class for class-detector
		local lines = {
			"class MyClass {",
			"public:",
			"	MyClass();",
			"};",
		}
		create_cpp_buffer(lines)
		vim.api.nvim_win_set_cursor(0, { 1, 6 })

		local cpp_tools = require("cpp-tools")
		local captured_header_path = nil

		cpp_tools.setup({
			enable_cmake_integration = false,
			customisations = {
				get_project_root_fn = function()
					return project_root
				end,
				add_gtest = {
					prompt_module_name_fn = function(default_value)
						return default_value
					end,
					fill_test_content_fn = function(header_relative, module_namespaces, module_name, full_test_path)
						captured_header_path = header_relative
						vim.fn.writefile({ "// Test content for " .. module_name }, full_test_path)
					end,
				},
			},
		})

		-- ── Test scenario execution ──
		local add_gtest = require("cpp-tools.tools.add-gtest")
		add_gtest.run()

		-- ── Result verification ──
		local expected_test_path = project_root .. "/tests/MyClassTests.cpp"
		assert(
			vim.fn.filereadable(expected_test_path) == 1,
			"Test file should exist: " .. expected_test_path
		)

		local content_lines = vim.fn.readfile(expected_test_path)
		assert(
			#content_lines > 0 and content_lines[1] == "// Test content for MyClassTests",
			"Test file should contain custom content, got: " .. tostring(content_lines[1])
		)

		assert(
			captured_header_path == "MyClass.h",
			"Expected header_relative 'MyClass.h', got: " .. tostring(captured_header_path)
		)
	end)
end

function tests.test_add_gtest_run_with_namespace()
	-- ── Environment preparation ──
	with_tmp_dir(function(tmpdir)
		local project_root = tmpdir
		vim.fn.mkdir(project_root .. "/.git", "p")
		vim.fn.chdir(project_root)

		local lines = {
			"namespace ns1 {",
			"namespace ns2 {",
			"class MyClass {",
			"public:",

			"};",
			"}  // namespace ns2",
			"}  // namespace ns1",
		}
		create_cpp_buffer(lines)
		vim.api.nvim_win_set_cursor(0, { 3, 6 })

		local cpp_tools = require("cpp-tools")
		local captured_header_path = nil
		local captured_module_name = nil

		cpp_tools.setup({
			enable_cmake_integration = false,
			customisations = {
				get_project_root_fn = function()
					return project_root
				end,
				add_gtest = {
					prompt_module_name_fn = function(default_value)
						return default_value
					end,
					fill_test_content_fn = function(header_relative, module_namespaces, module_name, full_test_path)
						captured_header_path = header_relative
						captured_module_name = module_name
						vim.fn.writefile({ "// test" }, full_test_path)
					end,
				},
			},
		})

		-- ── Test scenario execution ──
		local add_gtest = require("cpp-tools.tools.add-gtest")
		add_gtest.run()

		-- ── Result verification ──
		local expected_test_path = project_root .. "/tests/ns1/ns2/MyClassTests.cpp"
		assert(
			vim.fn.filereadable(expected_test_path) == 1,
			"Test file should exist: " .. expected_test_path
		)
		assert(
			captured_header_path == "ns1/ns2/MyClass.h",
			"Expected header_relative 'ns1/ns2/MyClass.h', got: " .. tostring(captured_header_path)
		)
		assert(
			captured_module_name == "MyClassTests",
			"Expected module_name 'MyClassTests', got: " .. tostring(captured_module_name)
		)
	end)
end


function tests.test_add_gtest_run_empty_module_name()
	-- ── Environment preparation ──
	with_tmp_dir(function(tmpdir)
		local project_root = tmpdir
		vim.fn.mkdir(project_root .. "/.git", "p")
		vim.fn.chdir(project_root)

		create_cpp_buffer({ "class MyClass {", "public:", "	MyClass();", "};" })
		vim.api.nvim_win_set_cursor(0, { 1, 6 })

		-- Capture notifications
		local original_notify = vim.notify
		local captured = {}
		vim.notify = function(msg, level, opts)
			table.insert(captured, { msg = msg, level = level })
		end

		local cpp_tools = require("cpp-tools")
		cpp_tools.setup({
			enable_cmake_integration = false,
			customisations = {
				get_project_root_fn = function()
					return project_root
				end,
				add_gtest = {
					prompt_module_name_fn = function(default_value)
						return "" -- user cancelled
					end,
				},
			},
		})

		-- Protect notify restore
		local ok, err = xpcall(function()
			-- ── Test scenario execution ──
			local add_gtest = require("cpp-tools.tools.add-gtest")
			add_gtest.run()
		end, function()
		end)
		vim.notify = original_notify
		if not ok then
			error(err)
		end

		-- ── Result verification ──
		assert(#captured > 0, "vim.notify should have been called")
		local last = captured[#captured]
		assert(
			last.msg:match("test module name cannot be empty") ~= nil,
			"Notification should indicate empty module name, got: " .. tostring(last.msg)
		)
		assert(
			last.level == vim.log.levels.ERROR,
			"Notification level should be ERROR, got: " .. tostring(last.level)
		)

		local test_path = project_root .. "/tests/"
		assert(
			vim.fn.isdirectory(test_path) == 0,
			"Tests directory should NOT be created when module name is empty"
		)
	end)
end

function tests.test_add_gtest_run_custom_module_name()
	-- ── Environment preparation ──
	with_tmp_dir(function(tmpdir)
		local project_root = tmpdir
		vim.fn.mkdir(project_root .. "/.git", "p")
		vim.fn.chdir(project_root)

		create_cpp_buffer({ "class MyClass {", "public:", "	MyClass();", "};" })
		vim.api.nvim_win_set_cursor(0, { 1, 6 })

		local cpp_tools = require("cpp-tools")
		local captured_module_name = nil

		cpp_tools.setup({
			enable_cmake_integration = false,
			customisations = {
				get_project_root_fn = function()
					return project_root
				end,
				add_gtest = {
					prompt_module_name_fn = function(default_value)
						return "MyCustomModule"
					end,
					fill_test_content_fn = function(header_relative, module_namespaces, module_name, full_test_path)
						captured_module_name = module_name
						vim.fn.writefile({ "// custom test" }, full_test_path)
					end,
				},
			},
		})

		-- ── Test scenario execution ──
		local add_gtest = require("cpp-tools.tools.add-gtest")
		add_gtest.run()

		-- ── Result verification ──
		assert(
			captured_module_name == "MyCustomModule",
			"Expected captured module_name 'MyCustomModule', got: " .. tostring(captured_module_name)
		)

		local expected_test_path = project_root .. "/tests/MyCustomModule.cpp"
		assert(
			vim.fn.filereadable(expected_test_path) == 1,
			"Test file should exist at custom path: " .. expected_test_path
		)
	end)
end

function tests.test_add_gtest_run_custom_module_name_whith_naspaces()
	-- ── Environment preparation ──
	with_tmp_dir(function(tmpdir)
		local project_root = tmpdir
		vim.fn.mkdir(project_root .. "/.git", "p")
		vim.fn.chdir(project_root)

		create_cpp_buffer({ "class MyClass {", "public:", "	MyClass();", "};" })
		vim.api.nvim_win_set_cursor(0, { 1, 6 })

		local cpp_tools = require("cpp-tools")
		local captured_module_name = nil

		cpp_tools.setup({
			enable_cmake_integration = false,
			customisations = {
				get_project_root_fn = function()
					return project_root
				end,
				add_gtest = {
					prompt_module_name_fn = function(default_value)
						return "Ns1::Ns2::Ns3::MyCustomModule"
					end,
					fill_test_content_fn = function(header_relative, module_namespaces, module_name, full_test_path)
						captured_module_name = module_name
						vim.fn.writefile({ "// custom test" }, full_test_path)
					end,
				},
			},
		})

		-- ── Test scenario execution ──
		local add_gtest = require("cpp-tools.tools.add-gtest")
		add_gtest.run()

		-- ── Result verification ──
		assert(
			captured_module_name == "MyCustomModule",
			"Expected captured module_name 'MyCustomModule', got: " .. tostring(captured_module_name)
		)

		local expected_test_path = project_root .. "/tests/Ns1/Ns2/Ns3/MyCustomModule.cpp"
		assert(
			vim.fn.filereadable(expected_test_path) == 1,
			"Test file should exist at custom path: " .. expected_test_path
		)
	end)
end
return tests
