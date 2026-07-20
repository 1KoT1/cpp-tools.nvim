
local M = {}

--- Default header relative path function.
--- Computes path relative to the headers directory.
--- @param namespaces string[] List of namespace names
--- @param class_name string The class name
--- @return string Relative path (e.g., "ns1/ns2/ClassName.h")
function M.header_relative_path(namespaces, class_name)
	return (#namespaces > 0 and table.concat(namespaces, '/') .. '/' or "") .. class_name .. '.h'
end

--- Default headers directory function.
--- Computes the base directory for header files.
--- @param project_root string Absolute path to the project root directory
--- @return string Headers directory path (e.g., "/project/includes")
function M.headers_dir(project_root)
	return project_root .. "/includes"
end

--- Default source relative path function.
--- Computes path relative to the sources directory.
--- @param namespaces string[] List of namespace names
--- @param class_name string The class name
--- @return string Relative path (e.g., "ns1/ns2/ClassName.cpp")
function M.source_relative_path(namespaces, class_name)
	return (#namespaces > 0 and table.concat(namespaces, '/') .. '/' or "") .. class_name .. '.cpp'
end

--- Default sources directory function.
--- Computes the base directory for source files.
--- @param project_root string Absolute path to the project root directory
--- @return string Sources directory path (e.g., "/project/src")
function M.sources_dir(project_root)
	return project_root .. "/src"
end

M.create_class = {}

--- Default function to determine the project root directory.
--- Walks up from the current buffer looking for well-known project markers
--- (.git, CMakeLists.txt, Makefile, .clangd). Raises an error listing every
--- searched marker if none is found.
--- @return string Absolute path to the project root
function M.get_project_root()
	local markers = { ".git", "CMakeLists.txt", "Makefile", ".clangd" }
	local root = vim.fs.root(0, {markers})
	if root == nil then
		error("Could not find project root. None of the markers found: " .. table.concat(markers, ", "))
	end
	return root
end

--- Default header content generation function.
--- Generates a C++ header file template with a #define include guard
--- following the Google C++ Style Guide (path-based macro naming).
--- The guard macro is formed by uppercasing all namespace components and
--- the class name, joined by underscores, suffixed with "_H_".
--- Example: ns1::ns2::MyClass -> #ifndef NS1_NS2_MYCLASS_H_
--- Writes the content directly to the specified header_path.
--- @param namespaces string[] List of namespace names
--- @param class_name string The class name
--- @param header_path string Absolute path to the header file to write
function M.create_class.fill_header_content(namespaces, class_name, header_path)
	-- Build the Google-style include guard macro
	-- Google style: PATH_BASED_FILE_NAME_H_
	local guard_parts = {}
	for _, ns in ipairs(namespaces) do
		table.insert(guard_parts, ns:upper())
	end
	table.insert(guard_parts, class_name:upper())
	local guard = table.concat(guard_parts, "_") .. "_H_"

	local lines = {}
	table.insert(lines, "#ifndef " .. guard)
	table.insert(lines, "#define " .. guard)
	table.insert(lines, "")

	-- Opening namespace blocks
	for _, ns in ipairs(namespaces) do
		table.insert(lines, "namespace " .. ns .. " {")
	end
	if #namespaces > 0 then
		table.insert(lines, "")
	end

	-- Class declaration
	table.insert(lines, "class " .. class_name .. " {")
	table.insert(lines, "public:")
	table.insert(lines, "	" .. class_name .. "();")
	table.insert(lines, "	~" .. class_name .. "();")
	table.insert(lines, "")
	table.insert(lines, "private:")
	table.insert(lines, "};")

	-- Closing namespace blocks (reverse order)
	if #namespaces > 0 then
		table.insert(lines, "")
		for i = #namespaces, 1, -1 do
			table.insert(lines, "}  // namespace " .. namespaces[i])
		end
	end

	table.insert(lines, "")
	table.insert(lines, "#endif // " .. guard)
	table.insert(lines, "")
	vim.fn.writefile(lines, header_path)
end

--- Default source content generation function.
--- Generates a C++ source file template with #include directive,
--- namespace wrapping, and empty constructor/destructor stubs.
--- Writes the content directly to the specified source_path.
--- @param namespaces string[] List of namespace names
--- @param class_name string The class name
--- @param header_path_for_include string Path to the corresponding header file for add in #include
--- @param full_source_path string Absolute path to the source file to write
function M.create_class.fill_source_content(namespaces, class_name, header_path_for_include, full_source_path)
	local lines = {}
	table.insert(lines, '#include "' .. header_path_for_include .. '"')
	table.insert(lines, "")

	-- Opening namespace blocks
	for _, ns in ipairs(namespaces) do
		table.insert(lines, "namespace " .. ns .. " {")
	end
	if #namespaces > 0 then
		table.insert(lines, "")
	end

	-- Closing namespace blocks (reverse order)
	if #namespaces > 0 then
		table.insert(lines, "")
		for i = #namespaces, 1, -1 do
			table.insert(lines, "}  // namespace " .. namespaces[i])
		end
	end

	table.insert(lines, "")
	vim.fn.writefile(lines, full_source_path)
end

return M
