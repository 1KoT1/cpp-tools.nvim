--- Helper class that creates a temporary directory on construction and
--- removes it (recursively) on destruction.  The directory path is obtained
--- via the shell command `mktemp -d -t cpp-tools.nvim.tests.XXXXXX`.
---
--- Automatic clean‑up relies on LuaJIT's `newproxy`, so the directory will
--- be removed when the GC collects the proxy userdata.  You can also call
--- `:destroy()` explicitly to release resources immediately.
function with_tmp_dir(action)
	local result = vim.fn.system({ "mktemp", "-d", "-t", "cpp-tools.nvim.tests.XXXXXX" })
	if vim.v.shell_error ~= 0 or result == "" then
		error("Failed to create temporary directory via mktemp")
	end
	-- Remove trailing newline
	local tmpdir = result:gsub("\n$", "")

	local ok, err = xpcall(action, debug.traceback, tmpdir)

	vim.fn.system({ "rm", "-rf", tmpdir })

	if not ok then
		error(err)
	end
end

return with_tmp_dir
