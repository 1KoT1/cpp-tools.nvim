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

		--- Custom function to compute the absolute path to a source file.
		--- Signature: (project_root: string, namespaces: string[], class_name: string) -> string
		--- Returns e.g. "/project/src/ns1/ns2/ClassName.cpp"
		source_path_fn = defaults_f.source_path,

		--- Custom function to compute path relative to the tests directory.
		--- Signature: (namespaces: string[], module_name: string) -> string
		--- Returns e.g. "ns1/ns2/MyClassTests.cpp"
		test_relative_path_fn = defaults_f.test_relative_path,

		--- Custom function to compute the tests base directory.
		--- Signature: (project_root: string) -> string
		--- Returns e.g. "/project/tests"
		tests_dir_fn = defaults_f.tests_dir,

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
		},

		add_gtest = {
			--- Custom function to prompt the user for the test module name.
			--- Signature: (default_value: string) -> string
			--- Returns the module name entered by the user, or empty string if cancelled.
			--- Default calls vim.fn.input. Override this for testing.
			prompt_module_name_fn = defaults_f.add_gtest.prompt_module_name,

			--- Custom function to generate and write the Google Test source file content.
			--- Signature: (header_relative_path: string, module_namespaces: string[], module_name: string, full_test_path: string) -> nil
			--- Writes the test file directly at full_test_path. Default implements
			--- an #include of the class header, gtest include, namespace wrapping,
			--- and a simple TEST() stub.
			fill_test_content_fn = defaults_f.add_gtest.fill_test_content,
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
