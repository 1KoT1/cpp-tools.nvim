-- Tests for cpp-tools.nvim class-detector tool
-- Run with: nvim --cmd "set rtp+=`pwd`" --headless -c "lua dofile('tests/init.lua')" -c "qa"
local test_dir = debug.getinfo(1, "S").source:match("@?(.*/)")
local lua_dir = test_dir .. "../lua/"
package.path = lua_dir .. "?.lua;"
	.. lua_dir .. "?/init.lua;"
	.. package.path
local tests = {}
local function load_class_detector()
	package.loaded["cpp-tools.tools.class-detector"] = nil
	return require("cpp-tools.tools.class-detector")
end
local function create_cpp_buffer(lines)
	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_set_current_buf(buf)
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.bo[buf].filetype = "cpp"
	pcall(vim.treesitter.get_parser, buf, "cpp")
	return buf
end
function tests.test_class_detector_cursor_on_class_declaration()
	local class_detector = load_class_detector()
	local lines = {"class MyClass {", "public:", "\tMyClass();", "};",}
	local buf = create_cpp_buffer(lines)
	vim.api.nvim_win_set_cursor(0, { 1, 6 })
	local class_name, namespaces = class_detector.detect()
	assert(class_name == "MyClass", "Expected 'MyClass', got: " .. tostring(class_name))
	assert(type(namespaces) == "table" and #namespaces == 0,
		"Expected empty namespaces, got: " .. vim.inspect(namespaces))
end
function tests.test_class_detector_cursor_inside_class_body()
	local class_detector = load_class_detector()
	local lines = {"class MyClass {", "public:", "\tMyClass();", "\tvoid foo();", "};",}
	local buf = create_cpp_buffer(lines)
	vim.api.nvim_win_set_cursor(0, { 3, 2 })
	local class_name, namespaces = class_detector.detect()
	assert(class_name == "MyClass", "Expected 'MyClass' from class body, got: " .. tostring(class_name))
end
function tests.test_class_detector_class_in_namespace()
	local class_detector = load_class_detector()
	local lines = {"namespace ns1 {", "namespace ns2 {", "class MyClass {", "public:", "\tMyClass();", "};", "}  // namespace ns2", "}  // namespace ns1",}
	local buf = create_cpp_buffer(lines)
	vim.api.nvim_win_set_cursor(0, { 3, 6 })
	local class_name, namespaces = class_detector.detect()
	assert(class_name == "MyClass", "Expected 'MyClass', got: " .. tostring(class_name))
	assert(type(namespaces) == "table" and #namespaces == 2,
		"Expected 2 namespaces, got: " .. vim.inspect(namespaces))
	assert(namespaces[1] == "ns1", "Expected ns1, got: " .. tostring(namespaces[1]))
	assert(namespaces[2] == "ns2", "Expected ns2, got: " .. tostring(namespaces[2]))
end
function tests.test_class_detector_method_implementation()
	local class_detector = load_class_detector()
	local lines = {"class MyClass {", "public:", "\tvoid foo();", "};", "", "void MyClass::foo() {", "\t// impl", "}",}
	local buf = create_cpp_buffer(lines)
	vim.api.nvim_win_set_cursor(0, { 6, 10 })
	local class_name, namespaces = class_detector.detect()
	assert(class_name ~= nil, "Expected non-nil class_name from method impl, got: " .. tostring(class_name))
end
function tests.test_class_detector_only_one_class_in_buffer()
	local class_detector = load_class_detector()
	local lines = {"// c", "#include <vector>", "", "class MyClass {", "public:", "\tMyClass();", "};",}
	local buf = create_cpp_buffer(lines)
	vim.api.nvim_win_set_cursor(0, { 2, 5 })
	local class_name, namespaces = class_detector.detect()
	assert(class_name == "MyClass", "Expected 'MyClass' when only class, got: " .. tostring(class_name))
end
function tests.test_class_detector_no_class_in_file()
	local class_detector = load_class_detector()
	local lines = {"#include <iostream>", "", "int main() {", "\treturn 0;", "}",}
	local buf = create_cpp_buffer(lines)
	vim.api.nvim_win_set_cursor(0, { 3, 5 })
	local class_name, namespaces = class_detector.detect()
	assert(class_name == nil, "Expected nil, got: " .. tostring(class_name))
	assert(namespaces == nil, "Expected nil namespaces, got: " .. vim.inspect(namespaces))
end
function tests.test_class_detector_not_cpp_buffer()
	local class_detector = load_class_detector()
	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_set_current_buf(buf)
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, {"class MyClass {};"})
	vim.bo[buf].filetype = "lua"
	local ok, err = pcall(class_detector.detect)
	assert(not ok, "Expected error for non-C++ buffer")
	assert(string.find(err, "not a C/C++ file", 1, true) ~= nil,
		"Expected not-C++ error, got: " .. tostring(err))
end
function tests.test_class_detector_multiple_classes_ambiguous()
	local class_detector = load_class_detector()
	local lines = {"class ClassA {", "public:", "\tvoid foo();", "};", "", "class ClassB {", "public:", "\tvoid bar();", "};",}
	local buf = create_cpp_buffer(lines)
	vim.api.nvim_win_set_cursor(0, { 5, 0 })
	local class_name, namespaces = class_detector.detect()
	assert(class_name == nil, "Expected nil when ambiguous, got: " .. tostring(class_name))
	assert(namespaces == nil, "Expected nil namespaces when ambiguous, got: " .. vim.inspect(namespaces))
end
return tests
