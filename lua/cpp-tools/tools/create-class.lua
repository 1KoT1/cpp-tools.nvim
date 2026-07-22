-- cpp-tools.nvim
-- Create Class tool — generates C++ class header and source files
--
-- Parses a user input line of the form:
--   create class MyClass
--   create class ns1::MyClass
--   create class ns1::ns2::MyClass
-- and creates the corresponding .h and .cpp files.

local M = {}

--- Split a string into namespace parts and class name.
--- Assumes the line starts with "create class ".
--- The remaining part is split by "::". The last element is the class name,
--- everything before it are namespace components.
--- @param line string The current buffer line
--- @return string[]|nil namespaces List of namespace names (may be empty)
--- @return string|nil class_name The class name
function M.parse(line)
	if not line or line == "" then
		return nil, nil
	end

	-- Strip leading whitespace and the "create class " prefix
	local trimmed = line:match("^%s*create%s+class%s+(.+)$")
	if not trimmed then
		return nil, nil
	end

	-- Trim trailing whitespace from the remaining part
	trimmed = vim.trim(trimmed)
	if trimmed == "" then
		return nil, nil
	end

	-- Split by "::"
	local parts = vim.split(trimmed, "::", { plain = true })
	if #parts == 0 then
		return nil, nil
	end

	-- Last element is the class name, rest are namespaces
	local class_name = vim.trim(parts[#parts])
	local namespaces = {}
	for i = 1, #parts - 1 do
		local ns = vim.trim(parts[i])
		if ns ~= "" then
			table.insert(namespaces, ns)
		end
	end

	if class_name == "" then
		return nil, nil
	end

	return namespaces, class_name
end

--- Main entry point — called by a user command.
---
--- Parses the current buffer line for a class creation declaration,
--- determines header and source file paths, generates content, and writes
--- both files to disk. Uses custom path functions from the user config if
--- provided, otherwise falls back to the default implementations.
function M.run()
	-- Read the current line
	local line = vim.fn.getline(".")
	if not line or line == "" then
		vim.notify(
			"cpp-tools.nvim::create-class: current line is empty.\n"
			.. "Expected format: 'create class [ns::...]ClassName'",
			vim.log.levels.ERROR
		)
		return
	end

	-- Parse namespace(s) and class name
	local namespaces, class_name = M.parse(line)
	if not class_name then
		vim.notify(
			"cpp-tools.nvim::create-class: could not parse class name.\n"
			.. "Expected format: 'create class [ns::...]ClassName'\n"
			.. "Current line: " .. line,
			vim.log.levels.ERROR
		)
		return
	end

	-- Load user configuration
	local config = require("cpp-tools.config").get()

	-- Resolve the project root
	local ok, project_root = pcall(config.customisations.get_project_root_fn)
	if not ok then
		vim.notify("cpp-tools.nvim::create_class: " .. tostring(project_root), vim.log.levels.ERROR)
		return
	end

	-- Resolve header file path
	local header_relative = config.customisations.header_relative_path_fn(namespaces, class_name)
	local header_dir = config.customisations.headers_dir_fn(project_root)
	local header_path = header_dir .. "/" .. header_relative

	-- Create directories for header file if needed
	local header_parent_dir = vim.fn.fnamemodify(header_path, ":h")
	if vim.fn.isdirectory(header_parent_dir) == 0 then
		vim.fn.mkdir(header_parent_dir, "p")
	end

	-- Resolve source file path
	local source_path = config.customisations.source_path_fn(project_root, namespaces, class_name)

	-- Create directories for source file if needed
	local source_parent_dir = vim.fn.fnamemodify(source_path, ":h")
	if vim.fn.isdirectory(source_parent_dir) == 0 then
		vim.fn.mkdir(source_parent_dir, "p")
	end

	-- Generate and write both files using the configurable functions
	config.customisations.create_class.fill_header_content_fn(namespaces, class_name, header_path)
	config.customisations.create_class.fill_source_content_fn(namespaces, class_name, header_relative, source_path)

	-- Remove the "create class ..." line from the buffer
	local current_line = vim.fn.line(".")
	vim.api.nvim_buf_set_lines(0, current_line - 1, current_line, false, {})

	-- Attempt to integrate the new source file into CMake.
	local ok, err = pcall(function()
		require("cpp-tools.tools.cmake").integrate_create_class(project_root, source_path)
	end)
	if not ok then
		vim.notify(
			"cpp-tools.nvim::create-class: CMake integration failed: " .. tostring(err),
			vim.log.levels.WARN
		)
	end

	-- Open the header file in the current window
	vim.cmd("edit " .. vim.fn.fnameescape(header_path))
end

return M
