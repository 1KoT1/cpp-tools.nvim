--- Helper class that creates a temporary directory on construction and
--- removes it (recursively) on destruction.  The directory path is obtained
--- via the shell command `mktemp -d -t cpp-tools.nvim.tests.XXXXXX`.
---
--- Automatic clean‑up relies on LuaJIT's `newproxy`, so the directory will
--- be removed when the GC collects the proxy userdata.  You can also call
--- `:destroy()` explicitly to release resources immediately.
local TempDir = {}
TempDir.__index = TempDir

--- Create a new TempDir instance.
--- @return TempDir
function TempDir.new()
	local result = vim.fn.system({ "mktemp", "-d", "-t", "cpp-tools.nvim.tests.XXXXXX" })
	if vim.v.shell_error ~= 0 or result == "" then
		error("Failed to create temporary directory via mktemp")
	end
	-- Remove trailing newline
	local tmpdir = result:gsub("\n$", "")

	local self = setmetatable({ _path = tmpdir, _destroyed = false }, TempDir)

	-- Register automatic clean‑up via LuaJIT's newproxy __gc.
	local proxy = newproxy(true)
	local proxy_mt = getmetatable(proxy)
	proxy_mt.__gc = function()
		if not self._destroyed then
			self._destroyed = true
			vim.fn.system({ "rm", "-rf", tmpdir })
		end
	end
	self._proxy = proxy

	return self
end

--- Return the absolute path of the temporary directory.
--- @return string
function TempDir:path()
	return self._path
end

--- Explicitly remove the temporary directory.  Safe to call multiple times.
function TempDir:destroy()
	if self._destroyed then
		return
	end
	self._destroyed = true
	vim.fn.system({ "rm", "-rf", self._path })
end

function TempDir:__tostring()
	return "TempDir(" .. self._path .. ")"
end

return TempDir
