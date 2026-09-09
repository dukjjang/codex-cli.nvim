-- Run the installed CLI itself, preserving its composer, commands and key bindings.
local M = {}
local sessions, ui = {}, {}
local api = vim.api
local function valid(win)
	return win and api.nvim_win_is_valid(win)
end
local function geometry()
	local width = math.max(20, math.min(120, vim.o.columns - 4))
	local height = math.max(6, vim.o.lines - 6)
	return { relative = "editor", width = width, height = height,
		row = math.floor((vim.o.lines - height) / 2) - 1,
		col = math.floor((vim.o.columns - width) / 2) - 1 }
end
function M.close()
	vim.cmd("stopinsert")
	if valid(ui.win) then api.nvim_win_close(ui.win, true) end
	ui.win = nil
	if valid(ui.previous_win) then api.nvim_set_current_win(ui.previous_win) end
end
function M.open(cwd, command)
	local s = sessions[cwd]
	if s and s.job and not vim.deep_equal(s.command, command) then
		vim.notify("실행 중인 CLI의 설정·지침이 변경됐습니다. CLI에서 /quit 후 다시 여세요. 새 지침은 다음 CLI 실행에 적용됩니다.")
		command = s.command
	end
	if valid(ui.win) then
		api.nvim_set_current_win(ui.win)
		vim.cmd("startinsert")
		return
	end
	if vim.o.columns < 30 or vim.o.lines < 16 then
		vim.notify("Codex 창 크기를 조금 키워주세요 (30×16 이상).")
		return
	end
	if not s or not api.nvim_buf_is_valid(s.buf) or not s.job then
		s = { buf = api.nvim_create_buf(false, true), command = vim.deepcopy(command) }
		sessions[cwd] = s
		vim.bo[s.buf].bufhidden = "hide"
	end
	ui.previous_win = api.nvim_get_current_win()
	ui.win = api.nvim_open_win(s.buf, true, vim.tbl_extend("force", geometry(), {
		style = "minimal", border = "rounded", title = " Codex CLI · " .. vim.fs.basename(cwd) .. " ",
		footer = " Ctrl-\\ Ctrl-N → q 닫기 · i 입력 ", zindex = 60,
	}))
	vim.wo[ui.win].winblend = 0
	if not s.job then
		local started, job = pcall(vim.fn.jobstart, command, { term = true, cwd = cwd,
			on_exit = function() s.job = nil end,
		})
		s.job = started and job or nil
		if not s.job or s.job <= 0 then
			s.job = nil
			M.close()
			vim.notify("Codex CLI를 실행하지 못했습니다. 실행 경로를 확인하세요.", vim.log.levels.ERROR)
			return
		end
		-- Global terminal navigation/leader mappings must not consume CLI input.
		for _, mapping in ipairs(api.nvim_get_keymap("t")) do
			vim.keymap.set("t", mapping.lhs, mapping.lhs, { buffer = s.buf, nowait = true })
		end
		vim.keymap.set("n", "q", M.close, { buffer = s.buf, silent = true })
	end
	vim.cmd("startinsert")
end
function M.setup()
	local group = api.nvim_create_augroup("codex_cli_tui", { clear = true })
	api.nvim_create_autocmd("VimResized", { group = group, callback = function()
		if valid(ui.win) then
			if vim.o.columns < 30 or vim.o.lines < 16 then M.close(); return end
			api.nvim_win_set_config(ui.win, geometry())
		end
	end })
end
return M
