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
