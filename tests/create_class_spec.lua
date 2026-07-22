-- Tests for cpp-tools.nvim create class tool
--
-- Run with: nvim --cmd "set rtp+=`pwd`" --headless -c "lua dofile('tests/create_class_spec.lua')" -c "qa"

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

function tests.test_create_class_main_scenario()
	-- ── Environment preparation ──
	with_tmp_dir(function(tmpdir)
		local project_root = tmpdir
		vim.fn.mkdir(project_root .. "/.git", "p")
		vim.fn.chdir(project_root)

		local cpp_tools = require("cpp-tools")
		cpp_tools.setup({})

		local buf = vim.api.nvim_create_buf(false, true)
		vim.api.nvim_set_current_buf(buf)

		-- ── Test scenario execution ──
		vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "create class MyClass" })
		vim.api.nvim_win_set_cursor(0, { 1, 0 })
		vim.cmd("CppCreateClass")

		-- The command must remove the declaration line from the buffer
		assert(
			vim.api.nvim_buf_get_lines(buf, 0, -1, false)[1] ~= "create class MyClass",
			"Buffer line should be removed after class creation"
		)

		-- ── Result verification ──
		local expected_header = project_root .. "/includes/MyClass.h"
		local expected_source = project_root .. "/src/MyClass.cpp"

		assert(
			vim.fn.filereadable(expected_header) == 1,
			"Header file should exist: " .. expected_header
		)
		assert(
			vim.fn.filereadable(expected_source) == 1,
			"Source file should exist: " .. expected_source
		)

		local header_lines = vim.fn.readfile(expected_header)
		assert(#header_lines > 0, "Header file should not be empty")

		-- Google-style include guard
		assert(
			header_lines[1] == "#ifndef MYCLASS_H_",
			"Header line 1 should be the include guard #ifndef, got: "
			.. tostring(header_lines[1])
		)
		assert(
			header_lines[2] == "#define MYCLASS_H_",
			"Header line 2 should be the include guard #define, got: "
			.. tostring(header_lines[2])
		)
		assert(
			header_lines[#header_lines - 1] == "#endif // MYCLASS_H_",
			"Second-to-last line should close the include guard, got: "
			.. tostring(header_lines[#header_lines - 1])
		)

		-- Class declaration with constructor/destructor
		local has_class_decl = false
		local has_ctor = false
		local has_dtor = false
		for _, line in ipairs(header_lines) do
			if line == "class MyClass {" then
				has_class_decl = true
			end
			if line == "\tMyClass();" then
				has_ctor = true
			end
			if line == "\t~MyClass();" then
				has_dtor = true
			end
		end
		assert(has_class_decl, "Header should contain 'class MyClass {' declaration")
		assert(has_ctor, "Header should contain constructor 'MyClass();'")
		assert(has_dtor, "Header should contain destructor '~MyClass();'")

		-- Verify source file content
		local source_lines = vim.fn.readfile(expected_source)
		assert(#source_lines > 0, "Source file should not be empty")

		-- #include directive that references the header
		assert(
			source_lines[1]:match('^#include "MyClass%.h"$') ~= nil,
			"Source line 1 should #include the header, got: "
			.. tostring(source_lines[1])
		)
	end)
end

function tests.test_create_class_main_scenario_with_namespace()
	-- ── Environment preparation ──
	with_tmp_dir(function(tmpdir)
		local project_root = tmpdir
		vim.fn.mkdir(project_root .. "/.git", "p")

		vim.fn.chdir(project_root)

		local cpp_tools = require("cpp-tools")
		cpp_tools.setup({})

		local buf = vim.api.nvim_create_buf(false, true)
		vim.api.nvim_set_current_buf(buf)

		-- ── Test scenario execution ──
		vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "create class ns1::ns2::MyClass" })
		vim.api.nvim_win_set_cursor(0, { 1, 0 })
		vim.cmd("CppCreateClass")

		-- The command must remove the declaration line from the buffer
		assert(
			vim.api.nvim_buf_get_lines(buf, 0, -1, false)[1] ~= "create class MyClass",
			"Buffer line should be removed after class creation"
		)

		-- ── Result verification ──
		local expected_header = project_root .. "/includes/ns1/ns2/MyClass.h"
		local expected_source = project_root .. "/src/ns1/ns2/MyClass.cpp"

		assert(
			vim.fn.filereadable(expected_header) == 1,
			"Header file should exist: " .. expected_header
		)
		assert(
			vim.fn.filereadable(expected_source) == 1,
			"Source file should exist: " .. expected_source
		)

		-- Header: namespaced include guard
		local header_lines = vim.fn.readfile(expected_header)
		assert(
			header_lines[1] == "#ifndef NS1_NS2_MYCLASS_H_",
			"Header line 1 should have namespaced include guard, got: "
			.. tostring(header_lines[1])
		)
		assert(
			header_lines[#header_lines - 1] == "#endif // NS1_NS2_MYCLASS_H_",
			"Second-to-last line should close the namespaced include guard, got: "
			.. tostring(header_lines[#header_lines - 1])
		)

		-- Namespace wrapping in header
		local has_ns1_open = false
		local has_ns2_open = false
		local has_ns1_close = false
		local has_ns2_close = false
		for _, line in ipairs(header_lines) do
			if line == "namespace ns1 {" then has_ns1_open = true end
			if line == "namespace ns2 {" then has_ns2_open = true end
			if line == "}  // namespace ns1" then has_ns1_close = true end
			if line == "}  // namespace ns2" then has_ns2_close = true end
		end
		assert(has_ns1_open, "Header should open namespace ns1")
		assert(has_ns2_open, "Header should open namespace ns2")
		assert(has_ns1_close, "Header should close namespace ns1")
		assert(has_ns2_close, "Header should close namespace ns2")

		-- Source: namespace wrapping
		local source_lines = vim.fn.readfile(expected_source)
		assert(#source_lines > 0, "Source file should not be empty")

		local src_has_ns1_open = false
		local src_has_ns2_open = false
		local src_has_ns1_close = false
		local src_has_ns2_close = false
		for _, line in ipairs(source_lines) do
			if line == "namespace ns1 {" then src_has_ns1_open = true end
			if line == "namespace ns2 {" then src_has_ns2_open = true end
			if line == "}  // namespace ns1" then src_has_ns1_close = true end
			if line == "}  // namespace ns2" then src_has_ns2_close = true end
		end
		assert(src_has_ns1_open, "Source should open namespace ns1")
		assert(src_has_ns2_open, "Source should open namespace ns2")
		assert(src_has_ns1_close, "Source should close namespace ns1")
		assert(src_has_ns2_close, "Source should close namespace ns2")
	end)
end

function tests.test_customisation_get_project_root_fn()
	-- ── Environment preparation ──
	with_tmp_dir(function(tmpdir)
		local project_root = tmpdir

		-- Custom project-root function ignores markers/cwd and returns our path.
		-- It records whether it was invoked.
		local called = false
		local opts = {
			customisations = {
				get_project_root_fn = function()
					called = true
					return project_root
				end,
			},
		}

		local cpp_tools = require("cpp-tools")
		cpp_tools.setup(opts)

		local buf = vim.api.nvim_create_buf(false, true)
		vim.api.nvim_set_current_buf(buf)
		vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "create class MyClass" })
		vim.api.nvim_win_set_cursor(0, { 1, 0 })

		-- ── Test scenario execution ──
		vim.cmd("CppCreateClass")

		-- The command must remove the declaration line from the buffer
		assert(
			vim.api.nvim_buf_get_lines(buf, 0, -1, false)[1] ~= "create class MyClass",
			"Buffer line should be removed after class creation"
		)

		-- ── Result verification ──
		assert(called, "custom get_project_root_fn should have been called")
		assert(
			vim.fn.filereadable(project_root .. "/includes/MyClass.h") == 1,
			"Header should be created under the custom project root"
		)
		assert(
			vim.fn.filereadable(project_root .. "/src/MyClass.cpp") == 1,
			"Source should be created under the custom project root"
		)
	end)
end

function tests.test_customisation_headers_dir_fn()
	-- ── Environment preparation ──

	-- Auto-cleaned temporary directory acts as the sample project root.
	with_tmp_dir(function(tmpdir)
		local project_root = tmpdir

		-- Create a .git marker so the default get_project_root_fn can detect it
		vim.fn.mkdir(project_root .. "/.git", "p")

		-- Change cwd to the sample project so the default get_project_root_fn
		--    discovers the .git marker from the current working directory.
		vim.fn.chdir(project_root)

		-- Initialise the plugin with repalce by custom
		local cpp_tools = require("cpp-tools")
		cpp_tools.setup({
			customisations = {
				-- Custom headers directory: "<root>/my_headers" instead of "includes".
				headers_dir_fn = function(project_root)
					return project_root .. "/my_headers"
				end,
			},
		})

		-- Scratch buffer with the declaration line, cursor on the first line.
		local buf = vim.api.nvim_create_buf(false, true)
		vim.api.nvim_set_current_buf(buf)

		-- ── Test scenario execution ──
		vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "create class MyClass" })
		vim.api.nvim_win_set_cursor(0, { 1, 0 })
		vim.cmd("CppCreateClass")

		-- The command must remove the declaration line from the buffer
		assert(
			vim.api.nvim_buf_get_lines(buf, 0, -1, false)[1] ~= "create class MyClass",
			"Buffer line should be removed after class creation"
		)

		-- ── Result verification ──
		assert(
			vim.fn.filereadable(project_root .. "/my_headers/MyClass.h") == 1,
			"Header should be created under the custom headers directory"
		)
		assert(
			vim.fn.filereadable(project_root .. "/includes/MyClass.h") == 0,
			"Header should NOT be created under the default 'includes' directory"
		)
	end)
end

function tests.test_customisation_source_path_fn()
	-- ── Environment preparation ──

	-- Auto-cleaned temporary directory acts as the sample project root.
	with_tmp_dir(function(tmpdir)
		local project_root = tmpdir

		-- Create a .git marker so the default get_project_root_fn can detect it
		vim.fn.mkdir(project_root .. "/.git", "p")

		-- Change cwd to the sample project so the default get_project_root_fn
		--    discovers the .git marker from the current working directory.
		vim.fn.chdir(project_root)

		-- Initialise the plugin with replace by custom
		local cpp_tools = require("cpp-tools")
		cpp_tools.setup({
			customisations = {
				-- Custom source path: "<root>/my_sources/<namespaces>/MyClass.cpp"
				source_path_fn = function(project_root, namespaces, class_name)
					return project_root .. "/my_sources/" .. table.concat(namespaces, "/") .. "/" .. class_name .. ".cpp"
				end,
			},
		})

		-- Scratch buffer with the declaration line, cursor on the first line.
		local buf = vim.api.nvim_create_buf(false, true)
		vim.api.nvim_set_current_buf(buf)

		-- ── Test scenario execution ──
		vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "create class ns1::ns2::MyClass" })
		vim.api.nvim_win_set_cursor(0, { 1, 0 })
		vim.cmd("CppCreateClass")

		-- The command must remove the declaration line from the buffer
		assert(
			vim.api.nvim_buf_get_lines(buf, 0, -1, false)[1] ~= "create class ns1::ns2::MyClass",
			"Buffer line should be removed after class creation"
		)

		-- ── Result verification ──
		assert(
			vim.fn.filereadable(project_root .. "/my_sources/ns1/ns2/MyClass.cpp") == 1,
			"Source should be created under the custom source path"
		)
		assert(
			vim.fn.filereadable(project_root .. "/src/ns1/ns2/MyClass.cpp") == 0,
			"Source should NOT be created under the default 'src' directory"
		)
	end)
end

function tests.test_customisation_source_path_fn_relative()
	-- ── Environment preparation ──
	with_tmp_dir(function(tmpdir)
		local project_root = tmpdir

		-- Create a .git marker so the default get_project_root_fn can detect it
		vim.fn.mkdir(project_root .. "/.git", "p")

		-- Change cwd to the sample project so the default get_project_root_fn
		--    discovers the .git marker from the current working directory.
		vim.fn.chdir(project_root)

		-- Initialise the plugin with replace by custom
		local cpp_tools = require("cpp-tools")
		cpp_tools.setup({
			customisations = {
				-- Custom source path: "<root>/src/custom/MyClass.cpp" instead of default.
				source_path_fn = function(project_root, namespaces, class_name)
					return project_root .. "/src/custom/" .. class_name .. ".cpp"
				end,
			},
		})

		-- Scratch buffer with the declaration line, cursor on the first line.
		local buf = vim.api.nvim_create_buf(false, true)
		vim.api.nvim_set_current_buf(buf)

		-- ── Test scenario execution ──
		vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "create class MyClass" })
		vim.api.nvim_win_set_cursor(0, { 1, 0 })
		vim.cmd("CppCreateClass")

		-- The command must remove the declaration line from the buffer
		assert(
			vim.api.nvim_buf_get_lines(buf, 0, -1, false)[1] ~= "create class MyClass",
			"Buffer line should be removed after class creation"
		)

		-- ── Result verification ──
		assert(
			vim.fn.filereadable(project_root .. "/src/custom/MyClass.cpp") == 1,
			"Source should be created under the custom source path"
		)
		assert(
			vim.fn.filereadable(project_root .. "/src/MyClass.cpp") == 0,
			"Source should NOT be created under the default relative path"
		)
	end)
end

function tests.test_customisation_fill_header_content_fn()
	-- ── Environment preparation ──
	with_tmp_dir(function(tmpdir)
		local project_root = tmpdir

		-- Create a .git marker so the default get_project_root_fn can detect it
		vim.fn.mkdir(project_root .. "/.git", "p")

		-- Change cwd to the sample project so the default get_project_root_fn
		--    discovers the .git marker from the current working directory.
		vim.fn.chdir(project_root)

		-- Initialise the plugin with replace by custom
		local cpp_tools = require("cpp-tools")
		cpp_tools.setup({
			customisations = {
				create_class = {
					-- Custom header content: a single comment that embeds the class name.
					fill_header_content_fn = function(namespaces, class_name, header_path)
						local lines = {
							"// Custom header for " .. class_name,
							"// Generated by test",
						}
						vim.fn.writefile(lines, header_path)
					end,
				},
			},
		})

		-- Scratch buffer with the declaration line, cursor on the first line.
		local buf = vim.api.nvim_create_buf(false, true)
		vim.api.nvim_set_current_buf(buf)

		-- ── Test scenario execution ──
		vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "create class MyClass" })
		vim.api.nvim_win_set_cursor(0, { 1, 0 })
		vim.cmd("CppCreateClass")

		-- The command must remove the declaration line from the buffer
		assert(
			vim.api.nvim_buf_get_lines(buf, 0, -1, false)[1] ~= "create class MyClass",
			"Buffer line should be removed after class creation"
		)

		-- ── Result verification ──
		local expected_header = project_root .. "/includes/MyClass.h"
		assert(
			vim.fn.filereadable(expected_header) == 1,
			"Header file should exist: " .. expected_header
		)
		local header_lines = vim.fn.readfile(expected_header)
		assert(
			header_lines[1] == "// Custom header for MyClass",
			"Header should contain custom content, got: " .. tostring(header_lines[1])
		)
	end)
end

function tests.test_customisation_fill_source_content_fn()
	-- ── Environment preparation ──
	with_tmp_dir(function(tmpdir)
		local project_root = tmpdir

		-- Create a .git marker so the default get_project_root_fn can detect it
		vim.fn.mkdir(project_root .. "/.git", "p")

		-- Change cwd to the sample project so the default get_project_root_fn
		--    discovers the .git marker from the current working directory.
		vim.fn.chdir(project_root)

		-- Initialise the plugin with replace by custom
		local cpp_tools = require("cpp-tools")
		cpp_tools.setup({
			customisations = {
				create_class = {
					-- Custom source content: a single comment that embeds the header path.
					fill_source_content_fn = function(namespaces, class_name, header_path_for_include, full_source_path)
						local lines = {
							"// Custom source for " .. class_name,
							'#include "' .. header_path_for_include .. '"',
						}
						vim.fn.writefile(lines, full_source_path)
					end,
				},
			},
		})

		-- Scratch buffer with the declaration line, cursor on the first line.
		local buf = vim.api.nvim_create_buf(false, true)
		vim.api.nvim_set_current_buf(buf)

		-- ── Test scenario execution ──
		vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "create class MyClass" })
		vim.api.nvim_win_set_cursor(0, { 1, 0 })
		vim.cmd("CppCreateClass")

		-- The command must remove the declaration line from the buffer
		assert(
			vim.api.nvim_buf_get_lines(buf, 0, -1, false)[1] ~= "create class MyClass",
			"Buffer line should be removed after class creation"
		)

		-- ── Result verification ──
		local expected_source = project_root .. "/src/MyClass.cpp"
		assert(
			vim.fn.filereadable(expected_source) == 1,
			"Source file should exist: " .. expected_source
		)
		local source_lines = vim.fn.readfile(expected_source)
		assert(
			source_lines[1] == "// Custom source for MyClass",
			"Source should contain custom content, got: " .. tostring(source_lines[1])
		)
	end)
end

function tests.test_customisation_get_project_root_fn_error_published()
	-- ── Environment preparation ──
	with_tmp_dir(function(tmpdir)
		local project_root = tmpdir

		vim.fn.mkdir(project_root .. "/.git", "p")
		vim.fn.chdir(project_root)

		local expected_error = "custom project root error"
		local opts = {
			customisations = {
				get_project_root_fn = function()
					error(expected_error)
				end,
			},
		}

		local cpp_tools = require("cpp-tools")
		cpp_tools.setup(opts)

		-- Capture notification calls
		local original_notify = vim.notify
		local captured = {}
		vim.notify = function(msg, level, opts)
			table.insert(captured, { msg = msg, level = level })
		end

		local buf = vim.api.nvim_create_buf(false, true)
		vim.api.nvim_set_current_buf(buf)


		-- Protect notify restore so later tests are not affected
		local ok, err = xpcall(function()

			-- ── Test scenario execution ──
			vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "create class MyClass" })
			vim.api.nvim_win_set_cursor(0, { 1, 0 })
			vim.cmd("CppCreateClass")

			-- The command must NOT remove the declaration line on error
			assert(
				vim.api.nvim_buf_get_lines(buf, 0, -1, false)[1] == "create class MyClass",
				"Buffer line should be preserved when project root resolution fails"
			)

		end, function()
		-- restore in any case
	end)
	vim.notify = original_notify
	if not ok then
		error(err)
	end

	-- ── Result verification ──
	-- The plugin must have published an ERROR notification
	assert(#captured > 0, "vim.notify should have been called")
	local last = captured[#captured]
	assert(
		last.msg:match(expected_error) ~= nil,
		"notification should contain the error message, got: " .. tostring(last.msg)
	)
	assert(
		last.level == vim.log.levels.ERROR,
		"notification level should be ERROR, got: " .. tostring(last.level)
	)

	-- Files must not be created because project root resolution failed
	assert(
		vim.fn.filereadable(project_root .. "/includes/MyClass.h") == 0,
		"Header should NOT be created when project root resolution fails"
	)
	assert(
		vim.fn.filereadable(project_root .. "/src/MyClass.cpp") == 0,
		"Source should NOT be created when project root resolution fails"
	)
end)
end

return tests
