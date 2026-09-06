local M = {}
function M.check()
	vim.health.start("codex-cli.nvim")
	if vim.fn.has("nvim-0.11") == 1 then
		vim.health.ok("Neovim 0.11+ available")
	else
		vim.health.error("Neovim 0.11+ is required")
	end
	if vim.fn.executable("codex") == 1 then
		vim.health.ok("Codex CLI: " .. vim.fn.exepath("codex"))
		vim.health.info(
			"Run `codex login` on this machine before sending prompts. A CLI with `codex app-server` support is required."
		)
	else
		vim.health.warn(
			"codex is not in PATH. Install Codex CLI, or set chat.command to { '/path/to/codex', 'app-server' }."
		)
	end
	vim.health.info(
		"No tmux, Python, Node API client, or additional Neovim plugins are required by the native chat. Python 3 is used only for tests."
	)
	vim.health.info("History directory: " .. vim.fn.stdpath("state") .. "/codex-cli")
end
return M
