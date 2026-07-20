# cpp-tools.nvim

Collection of tools for coding on C++ in Neovim. Automates routine C++ project tasks so you can focus on code instead of boilerplate.

## Installation

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "1KoT1/cpp-tools.nvim",
  opts = {},
}
```

Using [packer.nvim](https://github.com/wbthomason/packer.nvim):

```lua
use {
  "1KoT1/cpp-tools.nvim",
  config = function()
    require("cpp-tools").setup({})
  end,
}
```

## Keymap recommendation

The plugin intentionally does not define any keymaps to avoid conflicts with your existing configuration. Common mappings are:

```lua
vim.keymap.set("n", "<Leader>c", "<cmd>CppCreateClass<CR>", { desc = "Create C++ class" })
vim.keymap.set("n", "<Leader>t", "<cmd>CppAddGTest<CR>", { desc = "Add Google Test for class" })
```

## Plugin dependencies

The plugin has no hard dependencies.

- [cmake-tools.nvim](https://github.com/CivitasV/cmake-tools.nvim) (optional)
  If installed, the CMake integration in the Create Class tool uses its active
  build directory and selected target. Without it, the plugin falls back to
  well-known build directory names (`build`, `cmake-build-*`, etc.) and request
  a user to choice a target.

## Tools

### Create Class

**Why:** Quickly scaffold a new C++ class with creating header and source files.

**How to use:** Write on a new line:

```text
create class [ns1::[ns2::[...]]]ClassName
```

Then run `:CppCreateClass`. For example:

```text
create class ns1::ns2::MyClass
```

This generates two files using the configured paths:

```text
<headers_dir>/<header_relative_path>
<sources_dir>/<source_relative_path>
```

With default settings this becomes:

```text
includes/ns1/ns2/MyClass.h
src/ns1/ns2/MyClass.cpp
```

After creating the files, the command removes the `create class …` line from the buffer and opens the fresh header file for editing.

If the project uses CMake, the new source file is automatically added to the selected CMake target.

**Customisation:** You can adapt path resolution and generated file content to your project style. See [Customisation — Create Class](#customisation-create-class).

### Add Google Test

**Why:** Quickly generate a Google Test source file for an existing C++ class.

**How to use:** Open a C++ file, place the cursor on or inside the class you want to test, and run `:CppAddGTest`. The tool detects the class under the cursor and asks you for the test module name.

The default module name is `<namespace>::<ClassName>Tests`.

For example, with the cursor on a class `ns1::ns2::MyClass`, the default module name is `ns1::ns2::MyClassTests`. After confirmation the tool creates:

```text
<tests_dir>/<class_namespaces>/<module_name>.cpp
```

With default settings this becomes:

```text
tests/ns1/ns2/MyClassTests.cpp
```
After creating the file, the command opens it for editing. If the project uses CMake, the new source file is automatically added to the selected CMake target.

**Customisation:** You can adapt the generated test content to your project style. See [Customisation — Add Google Test](#customisation-add-google-test).

## Customisation

You can adapt all tools to your project conventions by replacing callback functions in the `customisations` table passed to `setup()`.

### Common options

These callbacks are shared across tools and control project layout and root detection. All of them are optional; if omitted, built-in defaults are used.

- `header_relative_path_fn(namespaces, class_name) -> string`
  - Computes the path of the header relative to the headers base directory.
  - Must return a string such as `"ns1/ns2/MyClass.h"`. Usually used in the #include directive. 
  - You can see an example at a default implementation: [`header_relative_path`](https://github.com/1KoT1/cpp-tools.nvim/blob/main/lua/cpp-tools/defaults.lua)

- `headers_dir_fn(project_root) -> string`
  - Computes the absolute path to the headers base directory.
  - Must return a string representing an absolute directory path, for example `"/project/includes"`.
  - You can see an example at a default implementation: [`headers_dir`](https://github.com/1KoT1/cpp-tools.nvim/blob/main/lua/cpp-tools/defaults.lua)

- `source_relative_path_fn(namespaces, class_name) -> string`
  - Computes the path of the source file relative to the sources base directory.
  - Must return a string such as `"ns1/ns2/MyClass.cpp"`.
  - You can see an example at a default implementation: [`source_relative_path`](https://github.com/1KoT1/cpp-tools.nvim/blob/main/lua/cpp-tools/defaults.lua)

- `sources_dir_fn(project_root) -> string`
  - Computes the absolute path to the sources base directory.
  - Must return a string representing an absolute directory path, for example `"/project/src"`.
  - You can see an example at a default implementation: [`sources_dir`](https://github.com/1KoT1/cpp-tools.nvim/blob/main/lua/cpp-tools/defaults.lua)

- `get_project_root_fn() -> string`
  - Determines the project root directory.
  - Must return an absolute path to the project root. If the root cannot be determined, raise an error with a human-readable message explaining why.
  - If this function raises an error, the error is shown via `vim.notify()` at `ERROR` level and no files are created.
  - You can see an example at a default implementation: [`get_project_root`](https://github.com/1KoT1/cpp-tools.nvim/blob/main/lua/cpp-tools/defaults.lua) — searches for `.git`, `CMakeLists.txt`, `Makefile`, `.clangd`.

### Create Class

For the Create Class tool you can additionally override content generation.

- `fill_header_content_fn(namespaces, class_name, header_path) -> nil`
  - Generates and writes the header file content.
  - Must write the final content directly to `header_path`. You do not need to create the parent directory; the tool creates it automatically.
  - You can see an example at a default implementation: [`fill_header_content`](https://github.com/1KoT1/cpp-tools.nvim/blob/main/lua/cpp-tools/defaults.lua) — generates a Google-style include guard, class skeleton with constructor/destructor declarations, and namespace wrapping.

- `fill_source_content_fn(namespaces, class_name, header_path_for_include, full_source_path) -> nil`
  - Generates and writes the source file content.
  - Must write the final content directly to `full_source_path`. Use `header_path_for_include` for the `#include` directive so it matches the generated header location.
  - You can see an example at a default implementation: [`fill_source_content`](https://github.com/1KoT1/cpp-tools.nvim/blob/main/lua/cpp-tools/defaults.lua) — generates an `#include` directive, namespace wrapping, and empty constructor/destructor stubs.

Create Class also uses the [Common options](#common-options) above.

### Add Google Test

For the Add Google Test tool you can additionally override the test file content generation.

- `fill_test_content_fn(header_relative_path, module_namespaces, module_name, full_test_path) -> nil`
  - Generates and writes the Google Test source file content.
  - `header_relative_path` is the relative path to the class header for the `#include` directive (e.g. `"ns1/ns2/MyClass.h"`).
  - `module_namespaces` are the namespace parts parsed from the module name (e.g. `{"ns1", "ns2"}`).
  - `module_name` is the last component of the module name, used as the `TEST()` suite name.
  - Must write the final content directly to `full_test_path`. You do not need to create the parent directory; the tool creates it automatically.
  - You can see an example at a default implementation: [`fill_test_content`](https://github.com/1KoT1/cpp-tools.nvim/blob/main/lua/cpp-tools/defaults.lua) — generates an `#include` of the class header, `#include <gtest/gtest.h>`, namespace wrapping, and a simple `TEST()` stub.

Add Google Test also uses the [Common options](#common-options) above.

### CMake Integration

The Create Class tool can automatically add new source files to a CMake target.

- `enable_cmake_integration` (boolean)
  Enables or disables the automatic CMake integration. When enabled, after
  creating a source file the tool searches for an appropriate CMake target
  and appends the file to its source list.
  Default: `true`

The CMake integration optionally supports [cmake-tools.nvim](https://github.com/CivitasV/cmake-tools.nvim).
If the plugin is installed, its active build directory and selected target are
used. Without it, the plugin falls back to well-known build directory names
(`build`, `cmake-build-*`, etc.) and request a user to choice a target.

Example:

```lua
require("cpp-tools").setup({
  customisations = {
    header_relative_path_fn = function(namespaces, class_name)
      return table.concat(namespaces, "/") .. "/" .. class_name .. ".h"
    end,
    headers_dir_fn = function(project_root)
      return project_root .. "/include"
    end,
    source_relative_path_fn = function(namespaces, class_name)
      return table.concat(namespaces, "/") .. "/" .. class_name .. ".cpp"
    end,
    sources_dir_fn = function(project_root)
      return project_root .. "/lib"
    end,
    get_project_root_fn = function()
      return "/absolute/path/to/project"
    end,
    create_class = {
      fill_header_content_fn = function(namespaces, class_name, header_path)
        -- generate header content and write it to header_path
      end,
      fill_source_content_fn = function(namespaces, class_name, header_path_for_include, full_source_path)
        -- generate source content and write it to full_source_path
      end,
    },
    add_gtest = {
      fill_test_content_fn = function(header_relative_path, module_namespaces, module_name, full_test_path)
        -- generate gtest content and write it to full_test_path
      end,
    },
  },
})
```
