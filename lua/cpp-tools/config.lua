-- cpp-tools.nvim
-- Configuration module with default settings

local M = {}

local defaults_f = require("cpp-tools.defaults")

--- Default plugin configuration
local defaults = {
	--- Enable debugging output
	debug = false,

	--- Filetypes that the plugin activates for
	filetypes = { "cpp", "c", "h", "hpp" },
	enable_cmake_integration = true,

	customisations = {
		--- Custom function to compute path relative to the headers directory.
		--- Signature: (namespaces: string[], class_name: string) -> string
		--- Returns e.g. "ns1/ns2/ClassName.hpp"
		header_relative_path_fn = defaults_f.header_relative_path,

		--- Custom function to compute the headers base directory.
		--- Signature: (project_root: string) -> string
		--- Returns e.g. "/project/includes"
		headers_dir_fn = defaults_f.headers_dir,

		--- Custom function to compute path relative to the sources directory.
		--- Signature: (namespaces: string[], class_name: string) -> string
		--- Returns e.g. "ns1/ns2/ClassName.cpp"
		source_relative_path_fn = defaults_f.source_relative_path,

		--- Custom function to compute the sources base directory.
		--- Signature: (project_root: string) -> string
		--- Returns e.g. "/project/src"
		sources_dir_fn = defaults_f.sources_dir,

		--- Custom function to determine the project root directory.
		--- Signature: () -> string
		--- Returns the absolute path to the project root. Raises an error if the
		--- root cannot be determined. The error message should contain information about
		--- heuristics for user can understand a reason.
		get_project_root_fn = defaults_f.get_project_root,

		create_class = {
			--- Custom function to generate and write the header file content.
			--- Signature: (namespaces: string[], class_name: string, header_path: string) -> nil
			--- Writes the header file directly at header_path. Default implements a
			--- Google-style #define include guard and class skeleton with namespace
			--- wrapping.
			fill_header_content_fn = defaults_f.create_class.fill_header_content,

			--- Custom function to generate and write the source file content.
			--- Signature: (namespaces: string[], class_name: string, header_path_for_include: string, full_source_path: string) -> nil
			--- Writes the source file directly at source_path. Default implements an
			--- #include directive, namespace wrapping, and empty constructor/destructor stubs.
			fill_source_content_fn = defaults_f.create_class.fill_source_content,
		}
	},
}

--- Current merged configuration
M.options = defaults

--- Setup configuration, merging user options with defaults
--- @param opts table|nil User configuration options
function M.setup(opts)
	M.options = vim.tbl_deep_extend("keep", opts or {}, defaults)
end

--- Get the current configuration
--- @return table
function M.get()
	return M.options
end

return M
