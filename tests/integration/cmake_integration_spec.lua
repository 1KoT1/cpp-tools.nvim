-- Integration tests for cpp-tools.nvim CMake integration
--
-- Run with: nvim --cmd "set rtp+=`pwd`" --headless -c "lua dofile('tests/init.lua')" -c "qa"
--
-- These tests require the cmake utility to be installed.

local test_dir = debug.getinfo(1, "S").source:match("@?(.*/)") or "./"
local lua_dir = test_dir .. "../lua/"
package.path = lua_dir .. "?lua;"
.. lua_dir .. "?/init.lua;"
.. package.path

-- Check if cmake is available
vim.cmd("silent! !which cmake > /dev/null 2>&1")
local has_cmake = vim.v.shell_error == 0 and vim.fn.executable("cmake") == 1

-- Check if cmake-tools.nvim is available
local has_cmake_tools, _ = pcall(require, "cmake-tools")

-- Load shared test helpers (with_tmp_dir, etc.)
with_tmp_dir = dofile("tests/helpers.lua")

local tests = {}

function tests.test_integrate_create_class_adds_target_sources()
	-- ── Environment preparation ──
	assert(has_cmake, "INFRASTRUCTURE ERROR: cmake utility not available for integration test")
	assert(not has_cmake_tools, "INFRASTRUCTURE ERROR: This test for environment without cmake-tools.nvim plugin")

	with_tmp_dir(function(tmpdir)
		local project_root = tmpdir..'/project'
		vim.fn.mkdir(project_root, "p")
		vim.fn.mkdir(project_root .. "/build", "p")

		-- Create CMakeLists.txt with a single target
		local cmake_lists = [[
		cmake_minimum_required(VERSION 3.16)
		project(TestProject)

		add_executable(MyApp src/main.cpp)
		]]
		vim.fn.mkdir(project_root .. "/src", "p")
		vim.fn.writefile(vim.split(cmake_lists, "\n", { plain = true }), project_root .. "/CMakeLists.txt")
		vim.fn.writefile({ "int main() { return 0; }" }, project_root .. "/src/main.cpp")

		-- Run cmake to configure the project
		vim.fn.mkdir(project_root .. "/build", "p")
		local original_cwd = vim.fn.getcwd()
		vim.fn.chdir(project_root)
		local cmake_result = vim.fn.system({ "cmake", "-S", ".", "-B", "build" })
		vim.fn.chdir(original_cwd)
		if vim.v.shell_error ~= 0 then
			error("INFRASTRUCTURE ERROR: cmake configure failed for test project: "..cmake_result)
		end

		-- ── Test scenario execution ──
		-- Initialize config with defaults (enable_cmake_integration = true)
		local config = require("cpp-tools.config")
		config.setup({})

		vim.fn.chdir(project_root)

		-- Create a mock source file path (the file doesn't need to exist for integrate_create_class)
		local source_path = project_root .. "/src/NewClass.cpp"

		-- Call integrate_create_class
		local cmake = require("cpp-tools.tools.cmake")
		cmake.integrate_create_class(project_root, source_path)

		vim.fn.chdir(original_cwd)

		-- ── Verifications ──
		-- Check that the new source was added inside the add_executable() block.
		local lines = vim.fn.readfile(project_root .. "/CMakeLists.txt")
		local found = false
		for _, line in ipairs(lines) do
			if line:match("add_executable") and line:match("MyApp") and line:match("NewClass%.cpp") then
				found = true
				break
			end
		end
		assert(found, "Fail to add a source file into a cmake target")

		-- Note: This test may fail in headless mode due to timing issues with cmake File API
		-- The important thing is that we attempt the integration
	end)
end

function tests.test_integrate_create_class_adds_target_sources_multi_lines()
	-- ── Environment preparation ──
	assert(has_cmake, "INFRASTRUCTURE ERROR: cmake utility not available for integration test")
	assert(not has_cmake_tools, "INFRASTRUCTURE ERROR: This test for environment without cmake-tools.nvim plugin")

	with_tmp_dir(function(tmpdir)
		local project_root = tmpdir..'/project'
		vim.fn.mkdir(project_root, "p")
		vim.fn.mkdir(project_root .. "/build", "p")

		-- Create CMakeLists.txt with a multi-line target
		local cmake_lists = [[
		cmake_minimum_required(VERSION 3.16)
		project(TestProject)

		add_executable(MyApp
		src/main.cpp
		src/OldClass.cpp)
		]]
		vim.fn.mkdir(project_root .. "/src", "p")
		vim.fn.writefile(vim.split(cmake_lists, "\n", { plain = true }), project_root .. "/CMakeLists.txt")
		vim.fn.writefile({ "int main() { return 0; }" }, project_root .. "/src/main.cpp")
		vim.fn.writefile({ "class OldClass { };" }, project_root .. "/src/OldClass.cpp")

		-- Run cmake to configure the project
		vim.fn.mkdir(project_root .. "/build", "p")
		local original_cwd = vim.fn.getcwd()
		vim.fn.chdir(project_root)
		local cmake_result = vim.fn.system({ "cmake", "-S", ".", "-B", "build" })
		vim.fn.chdir(original_cwd)
		if vim.v.shell_error ~= 0 then
			error("INFRASTRUCTURE ERROR: cmake configure failed for test project: " .. cmake_result)
		end

		-- ── Test scenario execution ──
		local config = require("cpp-tools.config")
		config.setup({})

		vim.fn.chdir(project_root)

		local source_path = project_root .. "/src/NewClass.cpp"

		local cmake = require("cpp-tools.tools.cmake")
		cmake.integrate_create_class(project_root, source_path)

		vim.fn.chdir(original_cwd)

		-- ── Verifications ──
		-- The new source must be added inside the add_executable() block.
		local lines = vim.fn.readfile(project_root .. "/CMakeLists.txt")

		local add_executable_idx = nil
		local close_idx = nil
		local new_class_idx = nil
		for idx, line in ipairs(lines) do
			if not add_executable_idx and line:match("add_executable") and line:match("MyApp") then
				add_executable_idx = idx
			end
			if add_executable_idx and not close_idx then
				if line:match("%)") then
					close_idx = idx
				end
			end
			if line:match("NewClass%.cpp") then
				new_class_idx = idx
			end
		end

		assert(add_executable_idx, "add_executable(MyApp) not found in CMakeLists.txt")
		assert(new_class_idx, "NewClass.cpp not found in CMakeLists.txt")
		assert(close_idx, "Closing parenthesis of add_executable not found")
		assert(
			new_class_idx >= add_executable_idx and new_class_idx <= close_idx,
			"NewClass.cpp must be inside add_executable(MyApp)...)"
		)

		-- Note: This test may fail in headless mode due to timing issues with cmake File API
		-- The important thing is that we attempt the integration
	end)
end

function tests.test_integrate_create_class_disabled_when_config_off()
	-- ── Environment preparation ──
	local config = require("cpp-tools.config")

	config.setup({ enable_cmake_integration = false })

	with_tmp_dir(function(tmpdir)
		local project_root = tmpdir..'/project'
		vim.fn.mkdir(project_root, "p")
		local source_path = tmpdir .. "/src/Foo.cpp"

		-- ── Test scenario execution ──
		-- Should be a no-op when integration is disabled
		local cmake = require("cpp-tools.tools.cmake")
		cmake.integrate_create_class(project_root, source_path)

		-- ── Verifications ──
		-- No CMakeLists.txt should exist (or be modified)
		local cmake_path = project_root .. "/CMakeLists.txt"
		assert(vim.fn.filereadable(cmake_path) == 0, "CMakeLists.txt should not be created")
	end)
end

function tests.test_integrate_create_class_no_cmake_project()
	-- ── Environment preparation ──
	with_tmp_dir(function(tmpdir)
		local project_root = tmpdir..'/project'
		vim.fn.mkdir(project_root, "p")
		-- No CMakeLists.txt - just a plain directory

		local source_path = project_root .. "/src/Bar.cpp"

		-- ── Test scenario execution ──
		-- Should be a no-op when not a cmake project
		local cmake = require("cpp-tools.tools.cmake")
		cmake.integrate_create_class(project_root, source_path)

		-- ── Verifications ──
		-- No CMakeLists.txt should exist (or be modified)
		local cmake_path = project_root .. "/CMakeLists.txt"
		assert(vim.fn.filereadable(cmake_path) == 0, "CMakeLists.txt should not be created")
	end)
end

function tests.test_integrate_create_class_uses_cmake_tools_build_dir()
	-- ── Environment preparation ──
	-- This test requires cmake-tools.nvim to be available
	-- If cmake-tools is not available, this is an infrastructure error
	assert(has_cmake, "INFRASTRUCTURE ERROR: cmake utility not available for integration test")
	assert(has_cmake_tools, "INFRASTRUCTURE ERROR: cmake-tools.nvim plugin not available for integration test")

	with_tmp_dir(function(tmpdir)
		local project_root = tmpdir..'/project'
		vim.fn.mkdir(project_root, "p")

		-- Create a minimal CMake project
		vim.fn.writefile({
			"cmake_minimum_required(VERSION 3.16)",
			"project(TestProject)",
			"add_executable(MyApp src/main.cpp)"
		}, project_root .. "/CMakeLists.txt")

		vim.fn.mkdir(project_root .. "/src", "p")
		vim.fn.writefile({ "int main() { return 0; }" }, project_root .. "/src/main.cpp")

		-- Change to project root so that cmake-tools finds the project and
		-- the CMake File API queries work correctly.
		local original_cwd = vim.fn.getcwd()
		vim.fn.chdir(project_root)

		-- Configure cmake-tools.nvim for this project.
		-- (config.cwd will be project_root because we chdir'd before setup.)
		local cmake_tools = require("cmake-tools")
		cmake_tools.setup({
			cmake_build_directory = "test-build/${variant:buildType}"
		})

		-- Select build type "Debug" via cmake-tools.nvim config API
		-- (equivalent to what :CMakeSelectBuildType + picking "Debug" would do)
		local cmake_config = cmake_tools.get_config()
		cmake_config.build_type = "Debug"
		cmake_config.variant = { buildType = "Debug" }

		-- Select build target "MyApp" via cmake-tools.nvim config API
		-- (equivalent to what :CMakeSelectBuildTarget + picking "MyApp" would do)
		cmake_config.build_target = { "MyApp" }

		-- Run cmake configure via cmake-tools.nvim (async via plenary.job).
		-- The executor "quickfix" is used by default.
		local generate_done = false
		cmake_tools.generate({ bang = false, fargs = {} }, function(_)
			generate_done = true
		end)
		vim.wait(30000, function()
			return generate_done
		end, 100)

		-- ── Test scenario execution ──
		-- Create a mock source file path (the file doesn't need to exist for integrate_create_class)
		local source_path = project_root .. "/src/NewClass.cpp"

		-- Call integrate_create_class
		local cmake = require("cpp-tools.tools.cmake")
		cmake.integrate_create_class(project_root, source_path)

		vim.fn.chdir(original_cwd)

		-- ── Verifications ──
		-- Check that the new source was added inside the add_executable() block.
		local lines = vim.fn.readfile(project_root .. "/CMakeLists.txt")
		local found = false
		for _, line in ipairs(lines) do
			if line:match("add_executable") and line:match("MyApp") and line:match("NewClass%.cpp") then
				found = true
				break
			end
		end
		assert(found, "Fail to add a source file into a cmake target")

		-- Note: This test may fail in headless mode due to timing issues with cmake File API
		-- The important thing is that we attempt the integration
	end)
end

function tests.test_integrate_create_class_uses_cmake_tools_select_target()
	-- ── Environment preparation ──
	-- This test requires cmake-tools.nvim to be available
	-- If cmake-tools is not available, this is an infrastructure error
	assert(has_cmake, "INFRASTRUCTURE ERROR: cmake utility not available for integration test")
	assert(has_cmake_tools, "INFRASTRUCTURE ERROR: cmake-tools.nvim plugin not available for integration test")

	with_tmp_dir(function(tmpdir)
		local project_root = tmpdir..'/project'
		vim.fn.mkdir(project_root, "p")

		-- Create a minimal CMake project
		vim.fn.writefile({
			"cmake_minimum_required(VERSION 3.16)",
			"project(TestProject)",
			"add_executable(MyApp src/main.cpp)",
			"add_executable(MyApp2 src/main.cpp)"
		}, project_root .. "/CMakeLists.txt")

		vim.fn.mkdir(project_root .. "/src", "p")
		vim.fn.writefile({ "int main() { return 0; }" }, project_root .. "/src/main.cpp")

		-- Change to project root so that cmake-tools finds the project and
		-- the CMake File API queries work correctly.
		local original_cwd = vim.fn.getcwd()
		vim.fn.chdir(project_root)

		-- Configure cmake-tools.nvim for this project.
		-- (config.cwd will be project_root because we chdir'd before setup.)
		local cmake_tools = require("cmake-tools")
		cmake_tools.setup({
			cmake_build_directory = "test-build/${variant:buildType}"
		})

		-- Select build type "Debug" via cmake-tools.nvim config API
		-- (equivalent to what :CMakeSelectBuildType + picking "Debug" would do)
		local cmake_config = cmake_tools.get_config()
		cmake_config.build_type = "Debug"
		cmake_config.variant = { buildType = "Debug" }

		-- Select build target "MyApp" via cmake-tools.nvim config API
		-- (equivalent to what :CMakeSelectBuildTarget + picking "MyApp" would do)
		cmake_config.build_target = { "MyApp" }

		-- Run cmake configure via cmake-tools.nvim (async via plenary.job).
		-- The executor "quickfix" is used by default.
		local generate_done = false
		cmake_tools.generate({ bang = false, fargs = {} }, function(_)
			generate_done = true
		end)
		vim.wait(30000, function()
			return generate_done
		end, 100)

		-- ── Test scenario execution ──
		-- Create a mock source file path (the file doesn't need to exist for integrate_create_class)
		local source_path = project_root .. "/src/NewClass.cpp"

		-- Call integrate_create_class
		local cmake = require("cpp-tools.tools.cmake")
		cmake.integrate_create_class(project_root, source_path)

		vim.fn.chdir(original_cwd)

		-- ── Verifications ──
		-- Check that the new source was added inside the add_executable() block.
		local lines = vim.fn.readfile(project_root .. "/CMakeLists.txt")
		local found = false
		for _, line in ipairs(lines) do
			if line:match("add_executable") and line:match("MyApp") and line:match("NewClass%.cpp") then
				found = true
				break
			end
		end
		assert(found, "Fail to add a source file into a cmake target")

		-- Note: This test may fail in headless mode due to timing issues with cmake File API
		-- The important thing is that we attempt the integration
	end)
end

function tests.test_integrate_create_class_uses_cmake_tools_build_dir_target_sources_multi_lines()
	-- ── Environment preparation ──
	-- This test requires cmake-tools.nvim to be available
	-- If cmake-tools is not available, this is an infrastructure error
	assert(has_cmake, "INFRASTRUCTURE ERROR: cmake utility not available for integration test")
	assert(has_cmake_tools, "INFRASTRUCTURE ERROR: cmake-tools.nvim plugin not available for integration test")

	with_tmp_dir(function(tmpdir)
		local project_root = tmpdir..'/project'
		vim.fn.mkdir(project_root, "p")

		-- Create a minimal CMake project
		vim.fn.writefile({
			"cmake_minimum_required(VERSION 3.16)",
			"project(TestProject)",
			"add_executable(MyApp",
			"	src/main.cpp",
			"	src/OldClass.cpp)",
		}, project_root .. "/CMakeLists.txt")

		vim.fn.mkdir(project_root .. "/src", "p")
		vim.fn.writefile({ "int main() { return 0; }" }, project_root .. "/src/main.cpp")
		vim.fn.writefile({ "class OldClass { };" }, project_root .. "/src/OldClass.cpp")

		-- Change to project root so that cmake-tools finds the project and
		-- the CMake File API queries work correctly.
		local original_cwd = vim.fn.getcwd()
		vim.fn.chdir(project_root)

		-- Configure cmake-tools.nvim for this project.
		-- (config.cwd will be project_root because we chdir'd before setup.)
		local cmake_tools = require("cmake-tools")
		cmake_tools.setup({
			cmake_build_directory = "test-build/${variant:buildType}"
		})

		-- Select build type "Debug" via cmake-tools.nvim config API
		-- (equivalent to what :CMakeSelectBuildType + picking "Debug" would do)
		local cmake_config = cmake_tools.get_config()
		cmake_config.build_type = "Debug"
		cmake_config.variant = { buildType = "Debug" }

		-- Select build target "MyApp" via cmake-tools.nvim config API
		-- (equivalent to what :CMakeSelectBuildTarget + picking "MyApp" would do)
		cmake_config.build_target = { "MyApp" }

		-- Run cmake configure via cmake-tools.nvim (async via plenary.job).
		-- The executor "quickfix" is used by default.
		local generate_done = false
		cmake_tools.generate({ bang = false, fargs = {} }, function(_)
			generate_done = true
		end)
		vim.wait(30000, function()
			return generate_done
		end, 100)

		-- ── Test scenario execution ──
		-- Create a mock source file path (the file doesn't need to exist for integrate_create_class)
		local source_path = project_root .. "/src/NewClass.cpp"

		-- Call integrate_create_class
		local cmake = require("cpp-tools.tools.cmake")
		cmake.integrate_create_class(project_root, source_path)

		vim.fn.chdir(original_cwd)

		-- ── Verifications ──
		-- The new source must be added inside the add_executable() block.
		local lines = vim.fn.readfile(project_root .. "/CMakeLists.txt")

		local add_executable_idx = nil
		local close_idx = nil
		local new_class_idx = nil
		for idx, line in ipairs(lines) do
			if not add_executable_idx and line:match("add_executable") and line:match("MyApp") then
				add_executable_idx = idx
			end
			if add_executable_idx and not close_idx then
				if line:match("%)") then
					close_idx = idx
				end
			end
			if line:match("NewClass%.cpp") then
				new_class_idx = idx
			end
		end

		assert(add_executable_idx, "add_executable(MyApp) not found in CMakeLists.txt")
		assert(new_class_idx, "NewClass.cpp not found in CMakeLists.txt")
		assert(close_idx, "Closing parenthesis of add_executable not found")
		assert(
			new_class_idx >= add_executable_idx and new_class_idx <= close_idx,
			"NewClass.cpp must be inside add_executable(MyApp)...)"
		)

		-- Note: This test may fail in headless mode due to timing issues with cmake File API
		-- The important thing is that we attempt the integration
	end)
end

return tests
