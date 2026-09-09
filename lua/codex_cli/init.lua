local M = {}
function M.setup(opts)
	if vim.fn.has("nvim-0.11") == 0 then
		vim.notify("codex-cli.nvim requires Neovim 0.11 or newer", vim.log.levels.ERROR)
		return
	end
	opts = opts or {}
	if opts.backend == "terminal" then
		require("codex_cli.config").set(opts)
		require("codex_cli.commands").setup()
		require("codex_cli.keymaps").setup()
		require("codex_cli.autoread").setup()
		require("codex_cli.terminal").setup_autoinsert()
		return
	end
	local chat = require("codex_cli.chat")
	chat.setup(opts.chat)
	local instructions = require("codex_cli.instructions")
	vim.api.nvim_create_user_command("CodexInstructions", function(args)
		if args.args ~= "" then
			local ok, err = instructions.register(args.args)
			vim.notify(ok and "지침 등록 완료: " .. instructions.path() or err,
				ok and vim.log.levels.INFO or vim.log.levels.ERROR)
			return
		end
		local content, err = instructions.load()
		vim.notify(content and (instructions.path() and "적용 지침: " .. instructions.path()
			or "등록된 지침이 없습니다. :CodexInstructions 파일경로로 등록하세요.") or err)
	end, { nargs = "?", complete = "file", force = true, desc = "Register or inspect external instructions" })
	vim.api.nvim_create_user_command("CodexInstructionsEdit", function()
		if not instructions.path() then vim.notify("먼저 :CodexInstructions 파일경로로 등록하세요."); return end
		chat.close()
		vim.api.nvim_cmd({ cmd = "edit", args = { instructions.path() } }, {})
	end, { force = true, desc = "Edit external instructions" })
	vim.api.nvim_create_user_command("CodexInstructionsClear", function()
		local ok, err = instructions.clear()
		vim.notify(ok and "지침 등록을 해제했습니다. 원본 문서는 유지됩니다." or err)
	end, { force = true, desc = "Unregister external instructions" })
	local commands = {
		CodexAsk = function(args)
			chat.open(args.range > 0 and args.line1 or nil, args.range > 0 and args.line2 or nil)
			if args.args ~= "" then
				chat.send(args.args)
			end
		end,
		CodexToggle = chat.toggle,
		CodexNew = chat.new,
		CodexStop = chat.cancel,
		CodexDiff = chat.diff,
		CodexMode = chat.mode,
		CodexModel = chat.model,
		CodexTerminal = function()
			require("codex_cli.terminal").toggle_terminal()
		end,
	}
	commands.CodexSend = commands.CodexAsk
	for name, callback in pairs(commands) do
		vim.api.nvim_create_user_command(
			name,
			callback,
			{ nargs = name == "CodexAsk" and "*" or name == "CodexSend" and "*" or 0, range = true, force = true }
		)
	end
	if opts.keymaps ~= false and not (type(opts.keymaps) == "table" and opts.keymaps.enabled == false) then
		local keys = type(opts.keymaps) == "table" and opts.keymaps or {}
		local function map(mode, key, fn, desc)
			if key ~= "" then
				vim.keymap.set(mode, key, fn, { silent = true, desc = desc })
			end
		end
		map("n", keys.ask or "<leader>aa", chat.open, "Codex 질문")
		map("x", keys.visual or keys.ask or "<leader>aa", function()
			local a, b = vim.fn.line("v"), vim.fn.line(".")
			vim.cmd("normal! \27")
			chat.open(math.min(a, b), math.max(a, b))
		end, "Codex 선택 코드 질문")
		map("n", keys.toggle or "<leader>at", chat.toggle, "Codex 대화창")
		map("n", "<leader>an", chat.new, "Codex 새 대화")
		map("n", "<leader>ad", chat.diff, "Codex 변경 내역")
	end
	M._ask_basic, M._ask_visual = chat.open, chat.open
end
return M
