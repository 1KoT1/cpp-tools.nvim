-- cpp-tools.nvim
-- CMake integration module — attempts to add newly created source files
-- to a selected CMake target automatically.

local utils = require('cpp-tools.utils')

local M = {}

local function get_build_dir(project_root)
	-- Prefer the active build directory from `cmake-tools.nvim` when
	-- available.
	local ok_cmake_tools, cmake_tools = pcall(require, "cmake-tools")
	if ok_cmake_tools then
		local build_dir = cmake_tools.get_config():prepare_build_directory(nil)

		if
			build_dir
			and vim.fn.isdirectory(build_dir) == 1
			and vim.fn.filereadable(build_dir .. "/CMakeCache.txt") == 1 then
			return build_dir
		end
	end

	-- Fallback to well-known build directory candidates.
	local candidates = {
		project_root .. "../build",
		project_root .. "/build",
		project_root .. "/Build",
		project_root .. "/cmake-build-debug",
		project_root .. "/cmake-build-release",
		project_root .. "/cmake-build-relwithdebinfo",
		project_root .. "/.build",
		project_root .. "/out",
		project_root .. "/cmake-build",
	}
	for _, candidate in ipairs(candidates) do
		if vim.fn.isdirectory(candidate) == 1 and vim.fn.filereadable(candidate .. "/CMakeCache.txt") == 1 then
			return candidate
		end
	end

	error('Fail to find build directory for project '..project_root)
end

local function codemodel_query_exist(build_dir)
	local query_dir = build_dir .. "/.cmake/api/v1/query"
	if vim.fn.isdirectory(query_dir) == 1 then
		local entries = vim.fn.readdir(query_dir)
		return vim.iter(entries):any(function(i) i:find("^codemodel") end)
	end
	return false
end

local function create_codemodel_query(sources_dir, build_dir)
	local query_dir = build_dir .. "/.cmake/api/v1/query"

	vim.fn.mkdir(query_dir, "p")

	local query_file = query_dir .. "/codemodel-v2"
	vim.fn.writefile({ "" }, query_file)

	-- Run cmake to process the query and generate replies.
	local result = vim.fn.system({ "cmake", '-S', sources_dir, '-B', build_dir })
	if vim.v.shell_error ~= 0 then
		error(
			"Failed to run cmake in build directory: "
			.. build_dir .. "\n" .. result
		)
	end
end

--- @param ms number Milliseconds to sleep.
local function sleep_ms(ms)
	local uv = vim.loop or vim.uv
	if uv and uv.sleep then
		uv.sleep(ms)
	else
		local start = vim.fn.reltimefloat(vim.fn.reltime())
		while vim.fn.reltimefloat(vim.fn.reltime()) - start < ms / 1000 do
			-- busy wait
		end
	end
end

--- Read a JSON file from disk and decode it.
---
--- Errors are raised if fail to read
---
--- @param file_path string Absolute path to a JSON file.
--- @return table Decoded JSON object.
local function read_json_file(file_path)
	if vim.fn.filereadable(file_path) ~= 1 then
		error("JSON file is not readable at: " .. file_path)
	end

	local json_text = table.concat(vim.fn.readfile(file_path), "\n")
	local ok, decoded = pcall(vim.json.decode, json_text)
	if not ok or type(decoded) ~= "table" then
		error("Failed to parse JSON file at: " .. file_path)
	end

	return decoded
end

--- @param api_reply_dir string Absolute path to the reply directory.
--- @return string Absolute path to the single index file.
--- Throws if no index file is found.
local function wait_index_file_ready(api_reply_dir)
	local max_attempts = 10
	local attempt = 0

	while attempt < max_attempts do
		if vim.fn.isdirectory(api_reply_dir) == 1 then
			local entries = vim.fn.readdir(api_reply_dir)

			local index_files = vim.iter(entries)
			:filter(function(i) return i:find("^index%-") and i:find("%.json$") end):totable()

			if #index_files == 1 then
				return api_reply_dir .. "/" .. index_files[1]
			end
		end

		-- No index file found yet — cmake may still be writing; wait and retry.
		attempt = attempt + 1
		if attempt < max_attempts then
			sleep_ms(100)
		end
	end

	error(
		"CMake File API index file not found after "
		.. max_attempts .. " attempts at: " .. api_reply_dir
	)
end

local function get_path_to_codemodel_from_index(build_dir)
	local api_reply_dir = build_dir .. "/.cmake/api/v1/reply"

	local index_path = wait_index_file_ready(api_reply_dir)

	local index = read_json_file(index_path)

	-- Locate the codemodel-v2 reply entry.
	-- The index may use either an "objects" array or a "reply" table.

	local objects = index.objects or {}
	local o = vim.iter(objects):find(function(i) return i.kind == "codemodel" and i.jsonFile end)
	local reply_filename = o and o.jsonFile or nil

	if not reply_filename then
		local reply = index.reply or {}
		local codemodel_entry = reply["codemodel-v2"] or reply.codemodel
		if type(codemodel_entry) == "table" and codemodel_entry.jsonFile then
			reply_filename = codemodel_entry.jsonFile
		end
	end

	if not reply_filename then
		error(
			"Failed to find codemodel-v2 reply in index file: " .. index_path
		)
	end

	return api_reply_dir .. "/" .. reply_filename
end

local function parse_targets(codemodel)
	local configurations = codemodel.configurations or {}
	if #configurations == 0 then
		error("No 'configurations' in CMake File API codemodel")
	end

	return vim.iter(configurations[1].targets or {})
	:filter(function(i)
		return not i.isGeneratorProvided and type(i.name) == 'string' and i.name ~= ''
	end)
	:map(function(i)
		return { name = i.name, json_file = i.jsonFile }
	end)
	:totable()
end

--- Read the individual target JSON file to resolve backtrace info
--- (cmake_lists_path and declared_line) for a previously selected target.
--- Returns the resolved path and line. Throws if the file is missing or unreadable.
--- @param target_json_file_path string Absolute path to the target JSON file.
--- @return string cmake_lists_path Path to the CMakeLists.txt, as stored in JSON.
--- @return number line 1-based line number in that file.
local function get_cmakelist_and_line_number_for_target(target_json_file_path)
	if vim.fn.filereadable(target_json_file_path) ~= 1 then
		error("Target JSON file not found at: " .. target_json_file_path)
	end

	local target_data = read_json_file(target_json_file_path)

	return utils.wrap_error(function()
		local backtrace_graph = target_data.backtraceGraph

		local node = backtrace_graph.nodes[target_data.backtrace + 1]

		local path = backtrace_graph.files[node.file + 1]
		local line = node.line

		return path, line
	end,
	'Failed to parse json '..target_json_file_path)
end

--- @return table[] List of target info objects:
---   { name: string, json_file: string }
local function get_all_targets(sources_dir, build_dir)
	if not codemodel_query_exist(build_dir) then
		create_codemodel_query(sources_dir, build_dir)
	end
	local codemodel_path = get_path_to_codemodel_from_index(build_dir)
	local codemodel = read_json_file(codemodel_path)
	return parse_targets(codemodel)
end

--- @param targets string[] Candidate target names.
--- @param prompt string Human readable prompt.
--- @return string|nil
local function prompt_target(targets, prompt)
	local choice = nil
	vim.ui.select(targets, { prompt = prompt }, function(selected)
		choice = selected
	end)
	return choice
end

local function find_active_target(sources_dir, build_dir)
	local targets = get_all_targets(sources_dir, build_dir)

	if #targets == 0 then
		error("No real CMake targets found in build directory: " .. build_dir)
	end

	if #targets == 1 then
		return targets[1]
	else
		local selected_target = nil
		-- Multiple targets: try to get the currently selected target from
		-- cmake-tools.nvim.
		local ok, cmake_tools = pcall(require, "cmake-tools")
		if ok then
			selected_target = unpack(cmake_tools.get_build_target())
		end

		if not selected_target then
			-- Fallback: let the user choose.
			local selected_target = prompt_target(
				vim.iter(targets):map(function(i) return i.name end):totable(),
				"Select CMake target for add a new source file:")
			if not choice then
				error('Target for add a source file not selected')
			end
		end

		selected = vim.iter(targets):find(function(i) return i.name == selected_target end)
		if not selected then
			error('Target for add a source file not selected')
		end
		return selected
	end
end

local function find_closing_parenthesis(lines, declared_line)
	local depth = 0
	for i = declared_line, #lines do
		local line = lines[i]
		for c in line:gmatch(".") do
			if c == "(" then
				depth = depth + 1
			elseif c == ")" then
				depth = depth - 1
				if depth == 0 then
					return i
				end
			end
		end
	end
end

--- @param cmake_lists_path string Absolute path to the CMakeLists.txt.
--- @param declared_line number 1-based line number where the target is declared.
--- @param source_path string Absolute path to the source file
local function add_source_to_target(cmake_lists_path, declared_line, source_path)
	local lines = vim.fn.readfile(cmake_lists_path)

	if declared_line < 1 or declared_line > #lines then
		error("Invalid declared_line: " .. tostring(declared_line))
	end

	-- Find the matching closing parenthesis of the add_*() command.
	local insert_idx = find_closing_parenthesis(lines, declared_line)

	if not insert_idx then
		error("Failed to find closing parenthesis in " .. cmake_lists_path .. " starting at line " .. tostring(declared_line))
	end

	-- Get source path relative cmake list path
	local cmake_dir = cmake_lists_path:match("(.*/)")
	local relative_source_path = vim.fs.relpath(cmake_dir, source_path)

	local close_line = lines[insert_idx]
	if insert_idx == declared_line then
		-- Single-line add_*(): insert the source before the closing parenthesis.
		lines[insert_idx] = close_line:gsub("%)%s*$", " " .. relative_source_path .. ")")
	else
		-- Multi-line add_*(): insert the source either on a new line before
		-- the closing parenthesis, or inline if the closing parenthesis
		-- shares the line with other tokens.
		if close_line:match("^%s*%)%s*$") then
			local indent = close_line:match("^(%s*)")
			table.insert(lines, insert_idx, indent .. relative_source_path)
		else
			lines[insert_idx] = close_line:gsub("%)%s*$", " " .. relative_source_path .. ")")
		end
	end

	vim.fn.writefile(lines, cmake_lists_path)
end

--- @param project_root string Absolute path to the project root.
--- @param source_path string Absolute path to the newly created source file.
function M.integrate_create_class(project_root, source_path)
	local config = require("cpp-tools.config").get()
	if not config or not config.enable_cmake_integration then
		return
	end
	local cmake_list_path = project_root .. "/CMakeLists.txt"
	if vim.fn.filereadable(cmake_list_path) ~= 1 then
		vim.notify("It isn't a cmake project", vim.log.levels.WARN)
		return
	end

	local build_dir = get_build_dir(project_root)

	local target_info = find_active_target(project_root, build_dir)
	local target_json_file_path = build_dir .. "/.cmake/api/v1/reply/" .. target_info.json_file

	local cmake_lists_path, declared_line = get_cmakelist_and_line_number_for_target(target_json_file_path)

	add_source_to_target(
		project_root .. "/" .. cmake_lists_path,
		declared_line,
		source_path)
end

return M
