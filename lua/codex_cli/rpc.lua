-- Newline-delimited JSON-RPC over Codex app-server stdio.
local M = {}
function M.new(command, cwd, on_event, on_exit)
	local self = { pending = {}, serial = 0, ready = false, queue = {}, tail = "", stderr = "" }
	function self:write(message)
		if not self.job then
			return false
		end
		return pcall(vim.fn.chansend, self.job, vim.json.encode(message) .. "\n")
	end
	function self:request(method, params, callback)
		self.serial = self.serial + 1
		local id = self.serial
		self.pending[id] = callback or function() end
		if not self:write({ id = id, method = method, params = params }) then
			local cb = self.pending[id]
			self.pending[id] = nil
			cb(nil, { message = "Codex 연결이 끊어졌습니다." })
			return
		end
		vim.defer_fn(function()
			if self.pending[id] then
				local cb = self.pending[id]
				self.pending[id] = nil
				cb(nil, { message = method .. " 요청 시간 초과" })
				self:stop()
			end
		end, 60000)
	end
	function self:when_ready(callback)
		if self.ready then
			callback()
		else
			table.insert(self.queue, callback)
		end
	end
	function self:stop()
		if self.job then
			vim.fn.jobstop(self.job)
		end
	end
	local function receive(line)
		local ok, msg = pcall(vim.json.decode, line)
		if not ok or type(msg) ~= "table" then
			return
		end
		if msg.method then
			on_event(msg, self)
		elseif msg.id and self.pending[msg.id] then
			local callback = self.pending[msg.id]
			self.pending[msg.id] = nil
			callback(msg.result, msg.error)
		end
	end
	local started, job = pcall(vim.fn.jobstart, command, {
		cwd = cwd,
		on_stdout = function(_, data)
			self.tail = self.tail .. table.concat(data, "\n")
			while true do
				local pos = self.tail:find("\n", 1, true)
				if not pos then
					break
				end
				local line = self.tail:sub(1, pos - 1)
				self.tail = self.tail:sub(pos + 1)
				receive(line)
			end
		end,
		on_stderr = function(_, data)
			self.stderr = (self.stderr .. table.concat(data, "\n")):sub(-4000)
		end,
		on_exit = function(_, code)
			self.job, self.ready = nil, false
			local pending = self.pending
			self.pending = {}
			self.queue = {}
			for _, cb in pairs(pending) do
				cb(nil, { message = "Codex 종료 (" .. code .. ")" })
			end
			on_exit(code, self.stderr)
		end,
	})
	self.job = started and job or nil
	if not self.job or self.job <= 0 then
		self.job = nil
		on_exit(-1, "codex 실행 파일을 확인하세요.")
		return self
	end
	self:request(
		"initialize",
		{ clientInfo = { name = "codex_cli_nvim", title = "Codex Neovim", version = "0.2.0" } },
		function(_, err)
			if err then
				on_exit(-1, err.message)
				self:stop()
				return
			end
			self:write({ method = "initialized", params = vim.empty_dict() })
			self.ready = true
			local queue = self.queue
			self.queue = {}
			for _, cb in ipairs(queue) do
				cb()
			end
		end
	)
	return self
end
return M
