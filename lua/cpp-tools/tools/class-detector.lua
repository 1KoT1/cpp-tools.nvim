-- cpp-tools.nvim
-- Class detector — determines the current C++ class from cursor position
-- using Treesitter.
--
-- Detection priority:
--   1. Cursor is on a class declaration → use that class
--   2. Cursor is inside a class body → use that class
--   3. Cursor is in a method implementation (qualified with ClassName::) → use that class
--   4. Only one class in the current file → use that class
--   5. Otherwise → nil

local M = {}

local utils = require("cpp-tools.utils")

--- Get a Treesitter node for a given position.
--- @param root TSNode Root node of the parse tree
--- @param row number 0-based line
--- @param col number 0-based column
--- @return TSNode|nil
local function get_node_at_position(root, row, col)
	return root:descendant_for_range(row, col, row, col)
end

--- Collect enclosing namespace names from namespace_definition ancestors.
--- Returns namespaces in order from outermost to innermost.
--- @param node TSNode Starting node
--- @return string[]
local function collect_namespaces(node)
	local namespaces = {}
	local current = node:parent()
	while current do
		if current:type() == "namespace_definition" then
			for child in current:iter_children() do
				if child:type() == "namespace_identifier"
				or child:type() == "identifier" then
					local ns_name = vim.treesitter.get_node_text(child, vim.api.nvim_get_current_buf())
					if ns_name then
						table.insert(namespaces, 1, ns_name)
					end
					break
				end
			end
		end
		current = current:parent()
	end
	return namespaces
end

--- Extract the class name from a class_specifier node.
--- @param node TSNode The class_specifier node
--- @return string|nil Class name
local function get_class_name_from_node(node)
	-- Check the "name:" named child field directly when supported
	local ok_fields, iter_fields = pcall(function()
		return node:iter_fields()
	end)
	if ok_fields and iter_fields then
		for field_name, field_node in node:iter_fields() do
			if field_name == "name" then
				return vim.treesitter.get_node_text(field_node, vim.api.nvim_get_current_buf())
			end
		end
	end
	-- Fallback: iterate children looking for identifier/template_type
	for child in node:iter_children() do
		local child_type = child:type()
		if child_type == "identifier"
			or child_type == "type_identifier"
			or child_type == "template_type"
			or child_type == "qualified_identifier" then
			return vim.treesitter.get_node_text(child, vim.api.nvim_get_current_buf())
		end
	end
	return nil
end

--- Try to extract the class name from a qualified identifier in a function
--- declarator.  For example, `MyClass::method` returns "MyClass".
--- @param node TSNode function_definition node
--- @return string|nil Class name
local function get_class_name_from_function(node)
	for child in node:iter_children() do
		if child:type() == "function_declarator" then
			for child2 in child:iter_children() do
				if child2:type() == "qualified_identifier" then
					for child3 in child2:iter_children() do
						if child3:type() == "identifier" then
							return vim.treesitter.get_node_text(child3, vim.api.nvim_get_current_buf())
						end
					end
				end
			end
		end
	end
	return nil
end

--- Check if a node is inside a class_specifier or is a class_specifier itself.
--- @param node TSNode Starting node
--- @return TSNode|nil The class_specifier node if found
local function find_enclosing_class(node)
	local current = node
	while current do
		if current:type() == "class_specifier" then
			return current
		end
		current = current:parent()
	end
	return nil
end

--- Find all class_specifier nodes in the entire tree.
--- @param root TSNode Root node
--- @return TSNode[] List of class_specifier nodes
local function find_all_class_nodes(root)
	local classes = {}
	local query = vim.treesitter.query.parse("cpp", [[
		(class_specifier) @class
	]])
	for pattern, node, metadata in query:iter_captures(root, vim.api.nvim_get_current_buf(), 0, -1) do
		table.insert(classes, node)
	end
	return classes
end



--- Detect the current class from the cursor position.
---
--- @return string|nil class_name The detected class name, or nil
--- @return string[]|nil namespaces The namespaces enclosing the class, or nil
function M.detect()
	if not utils.is_cpp_buffer() then
		error("cpp-tools.nvim::class-detector: buffer is not a C/C++ file")
	end

	-- Try to get a Treesitter parser for this buffer
	local ok, parser_or_err = pcall(vim.treesitter.get_parser, 0, "cpp")
	if not ok then
		error("cpp-tools.nvim::class-detector: failed to create Treesitter parser: " .. tostring(parser_or_err))
	end

	local tree = parser_or_err:parse()[1]
	if not tree then
		error("cpp-tools.nvim::class-detector: failed to parse buffer with Treesitter")
	end
	local root = tree:root()

	local cursor_row, cursor_col = unpack(vim.api.nvim_win_get_cursor(0))
	-- Treesitter uses 0-based line numbers
	local ts_row = cursor_row - 1

	-- 1. Get the node at the cursor position
	local cursor_node = get_node_at_position(root, ts_row, cursor_col)
	if not cursor_node then
		cursor_node = root
	end

	-- 2. Try to find an enclosing class_specifier
	local class_node = find_enclosing_class(cursor_node)

	if class_node then
		local class_name = get_class_name_from_node(class_node)
		if class_name then
			local namespaces = collect_namespaces(class_node)
			return class_name, namespaces
		end
	end

	-- 3. Try to find a method implementation (function_definition
	--    with qualified name like ClassName::method)
	local func_node = nil
	do
		local current = cursor_node
		while current do
			if current:type() == "function_definition" then
				func_node = current
				break
			end
			current = current:parent()
		end
	end

	if func_node then
		local class_name = get_class_name_from_function(func_node)
		if class_name then
			local namespaces = collect_namespaces(func_node)
			return class_name, namespaces
		end
	end

	-- 4. If only one class in the buffer, use it
	local all_classes = find_all_class_nodes(root)
	if #all_classes == 1 then
		local class_name = get_class_name_from_node(all_classes[1])
		if class_name then
			local namespaces = collect_namespaces(all_classes[1])
			return class_name, namespaces
		end
	end

	-- Could not determine the class
	return nil, nil
end

return M

