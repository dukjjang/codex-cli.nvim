-- Refresh loaded project buffers while an apply turn is running, including
-- when the user remains in Insert mode in the chat's separate input buffer.
local M = {}
local api, uv = vim.api, vim.uv or vim.loop
local function signature(path)
	local stat = uv.fs_stat(path)
	if not stat or stat.type ~= "file" then
		return nil
	end
	return table.concat({ stat.ino, stat.size, stat.mtime.sec, stat.mtime.nsec, stat.ctime.sec, stat.ctime.nsec }, ":")
end
local function reload(buf)
	if vim.bo[buf].modified then
		return false
	end
	local views = {}
	for _, win in ipairs(vim.fn.win_findbuf(buf)) do
		views[win] = api.nvim_win_call(win, vim.fn.winsaveview)
	end
	-- :checktime may defer until Insert mode ends. :edit reloads this specific
	-- clean buffer now, keeping Neovim's encoding, EOL and undo handling.
	local ok = pcall(api.nvim_buf_call, buf, function()
		vim.cmd("silent keepalt keepjumps edit")
	end)
	for win, view in pairs(views) do
		if api.nvim_win_is_valid(win) and api.nvim_win_get_buf(win) == buf then
			api.nvim_win_call(win, function()
				vim.fn.winrestview(view)
			end)
		end
	end
	return ok
end
function M.start(cwd)
	local self = { files = {} }
	local root = uv.fs_realpath(cwd) or cwd
	for _, buf in ipairs(api.nvim_list_bufs()) do
		if api.nvim_buf_is_loaded(buf) and vim.bo[buf].buftype == "" then
			local path = api.nvim_buf_get_name(buf)
			local real = uv.fs_realpath(path) or path
			if real:sub(1, #root + 1) == root .. "/" then
				self.files[buf] = { path = path, signature = signature(path) }
			end
		end
	end
	function self:refresh(force)
		local changed = false
		for buf, file in pairs(self.files) do
			if not api.nvim_buf_is_loaded(buf) or api.nvim_buf_get_name(buf) ~= file.path then
				self.files[buf] = nil
			else
				local stamp = signature(file.path)
				if stamp and stamp ~= file.signature then
					-- Wait for two matching samples during polling so a file being
					-- written is not reloaded mid-write. Completed tool events flush now.
					if (force or file.pending == stamp) and not vim.bo[buf].modified and reload(buf) then
						file.signature, file.pending = stamp, nil
						changed = true
					else
						file.pending = stamp
					end
				else
					file.pending = nil
				end
			end
		end
		if changed then
			vim.cmd("redraw")
		end
	end
	function self:stop()
		if self.timer then
			vim.fn.timer_stop(self.timer)
			self.timer = nil
		end
		self:refresh(true)
	end
	self.timer = vim.fn.timer_start(200, function()
		self:refresh(false)
	end, { ["repeat"] = -1 })
	return self
end
return M
