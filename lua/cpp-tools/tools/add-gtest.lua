-- cpp-tools.nvim
-- Add Google Test tool — generates a Google Test source file for the current
-- C++ class and adds it to the CMake target.
--
-- It detects the class under the cursor, asks the user for a test module name,
-- creates a test source file in the tests directory, and integrates it into CMake.

local M = {}

-- ── Helpers ────────────────────────────────────────────────────────────────

--- Parse a qualified name (with "::" separators) into namespace parts and the
--- final name component.
--- @param qualified string e.g. "ns1::ns2::MyClassTests"
--- @return string[] namespaces e.g. {"ns1", "ns2"}
--- @return string name e.g. "MyClassTests"
local function parse_qualified_name(qualified)
	if not qualified or qualified == "" then
		return {}, qualified or ""
	end
	local parts = vim.split(qualified, "::", { plain = true })
	local name = vim.trim(parts[#parts] or "")
	local namespaces = {}
	for i = 1, #parts - 1 do
		local ns = vim.trim(parts[i])
		if ns ~= "" then
			table.insert(namespaces, ns)
		end
	end
	return namespaces, name
end

--- Build the relative path for the test file.
--- Mirrors the class source file layout but uses `tests` instead of `src`.
--- @param class_namespaces string[] Namespaces of the class
--- @param module_name string The test module name (last component)
--- @return string Relative path e.g. "ns1/ns2/MyClassTests.cpp"
local function test_relative_path(class_namespaces, module_name)
	local parts = {}
	for _, ns in ipairs(class_namespaces) do
		table.insert(parts, ns)
	end
	table.insert(parts, module_name .. ".cpp")
	return table.concat(parts, "/")
end

-- ── Main entry point ──────────────────────────────────────────────────────

--- Main entry point — called by the :CppAddGTest user command.
function M.run()
	-- 1. Load config
	local config = require("cpp-tools.config").get()

	-- 2. Detect current class
	local class_detector = require("cpp-tools.tools.class-detector")
	local class_name, class_namespaces = class_detector.detect()

	-- 3. Build the default module name
	local default_module_name
	if class_name then
		local parts = {}
		for _, ns in ipairs(class_namespaces or {}) do
			table.insert(parts, ns)
		end
		table.insert(parts, class_name .. "Tests")
		default_module_name = table.concat(parts, "::")
	else
		default_module_name = "InputNamespace::InputNameTests"
	end

	-- 4. Ask the user for the test module name
	local module_qualified = vim.fn.input("Test module name: ", default_module_name)
	if module_qualified == "" then
		vim.notify(
			"cpp-tools.nvim::add-gtest: test module name cannot be empty.",
			vim.log.levels.ERROR
		)
		return
	end

	-- 5. Parse the module name into namespace parts and final name
	local module_namespaces, module_name = parse_qualified_name(module_qualified)

	if not module_name or module_name == "" then
		vim.notify(
			"cpp-tools.nvim::add-gtest: invalid test module name: " .. module_qualified,
			vim.log.levels.ERROR
		)
		return
	end

	-- 6. Determine the project root
	local ok, project_root = pcall(config.customisations.get_project_root_fn)
	if not ok then
		vim.notify("cpp-tools.nvim::add-gtest: " .. tostring(project_root), vim.log.levels.ERROR)
		return
	end

	-- 7. Compute the header include path (for the #include directive)
	local header_relative = config.customisations.header_relative_path_fn(
		class_namespaces or {}, class_name or ""
	)

	-- 8. Compute the test file path
	--    Mirror the class's source file layout but use tests/ instead of src/.
	local test_rel = test_relative_path(
		class_namespaces or {},
		module_name
	)
	local tests_dir = project_root .. "/tests"
	local test_path = tests_dir .. "/" .. test_rel

	-- 9. Create the tests directory if needed
	local test_parent_dir = vim.fn.fnamemodify(test_path, ":h")
	if vim.fn.isdirectory(test_parent_dir) == 0 then
		vim.fn.mkdir(test_parent_dir, "p")
	end

	-- 10. Generate and write the test file using the configurable function
	config.customisations.add_gtest.fill_test_content_fn(
		header_relative, module_namespaces, module_name, test_path
	)

	-- 11. Attempt to add the new file to CMake
	local ok_cmake, err_cmake = pcall(function()
		require("cpp-tools.tools.cmake").integrate_create_class(project_root, test_path)
	end)
	if not ok_cmake then
		vim.notify(
			"cpp-tools.nvim::add-gtest: CMake integration failed: " .. tostring(err_cmake),
			vim.log.levels.WARN
		)
	end

	-- 12. Open the test file
	vim.cmd("edit " .. vim.fn.fnameescape(test_path))
end

return M
