-- User-owned instructions; no bundled coding standards or skill dependencies.
local M = {}
local configured, load_error
local cached
local limit = 65536
local function registry()
	return vim.fn.stdpath("data") .. "/codex_cli/instructions.json"
end
local function read(path)
	local resolved = (vim.uv or vim.loop).fs_realpath(path)
	for _, buf in ipairs(vim.api.nvim_list_bufs()) do
		if vim.bo[buf].modified and (vim.api.nvim_buf_get_name(buf) == path
			or (resolved and (vim.uv or vim.loop).fs_realpath(vim.api.nvim_buf_get_name(buf)) == resolved)) then
			return nil, "지침 파일을 먼저 저장하세요: " .. path
		end
	end
	local stat = (vim.uv or vim.loop).fs_stat(path)
	if not stat then
		cached = nil
		return nil, "지침 파일을 읽을 수 없습니다: " .. path
	end
	local version = { resolved, stat.dev, stat.ino, stat.size, stat.mode, stat.mtime, stat.ctime }
	if cached and cached.path == path and vim.deep_equal(cached.version, version) then
		return cached.content
	end
	cached = nil
	local file = io.open(path, "rb")
	if not file then return nil, "지침 파일을 읽을 수 없습니다: " .. path end
	local content = file:read(limit + 1)
	file:close()
	if not content or vim.trim(content) == "" then return nil, "지침 파일이 비어 있습니다: " .. path end
	if #content > limit then return nil, "지침 파일은 64 KiB 이하여야 합니다: " .. path end
	if content:find("\0", 1, true) then return nil, "지침 파일은 텍스트여야 합니다: " .. path end
	cached = { path = path, version = version, content = content }
	return content
end
function M.setup(path)
	cached = nil
	configured, load_error = nil, nil
	if path == false then return end
	if path ~= nil then
		if type(path) ~= "string" or vim.trim(path) == "" then
			load_error = "chat.instructions_file은 파일 경로 또는 false여야 합니다."
			return
		end
		configured = vim.fn.fnamemodify(vim.fn.expand(path), ":p")
		return
	end
	if not (vim.uv or vim.loop).fs_stat(registry()) then return end
	local ok, data = pcall(function()
		return vim.json.decode(table.concat(vim.fn.readfile(registry()), "\n"))
	end)
	if not ok or type(data) ~= "table" or type(data.path) ~= "string" or data.path:sub(1, 1) ~= "/" then
		load_error = "저장된 지침 설정을 읽을 수 없습니다. :CodexInstructions 경로로 다시 등록하세요."
		return
	end
	configured = data.path
end
function M.load()
	if load_error then return nil, load_error end
	if not configured then return "", nil end
	local content, err = read(configured)
	if not content then return nil, err end
	return "Source: " .. vim.json.encode(configured) .. "\n" .. content, nil
end
function M.path()
	return configured
end
function M.register(path)
	path = vim.fn.fnamemodify(vim.fn.expand(path), ":p")
	local content, err = read(path)
	if not content then return nil, err end
	local ok, failure = pcall(function()
		vim.fn.mkdir(vim.fn.fnamemodify(registry(), ":h"), "p")
		local temporary = registry() .. "." .. vim.fn.getpid() .. ".tmp"
		assert(vim.fn.writefile({ vim.json.encode({ path = path }) }, temporary) == 0)
		if vim.fn.rename(temporary, registry()) ~= 0 then
			vim.fn.delete(temporary)
			error("지침 설정 저장 실패")
		end
	end)
	if not ok then return nil, tostring(failure) end
	configured, load_error = path, nil
	return true
end
function M.clear()
	if (vim.uv or vim.loop).fs_stat(registry()) and vim.fn.delete(registry()) ~= 0 then
		return nil, "지침 설정 삭제 실패"
	end
	configured, load_error = nil, nil
	cached = nil
	return true
end
function M.prompt(content)
	return "External instructions for this request (this snapshot replaces all earlier external-instruction snapshots):\n"
		.. (content == "" and "No external instructions are registered." or content)
		.. "\nEnd of external instructions.\n"
end
return M
