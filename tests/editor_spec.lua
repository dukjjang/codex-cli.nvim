-- Integration test with a clean configuration and real input loop.
local root = vim.fn.getcwd()
local child = vim.fn.jobstart({ vim.v.progpath, "--embed", "--headless", "-u", "NONE", "-i", "NONE" }, { rpc = true })
assert(child > 0)
local function lua(code, ...)
	return vim.rpcrequest(child, "nvim_exec_lua", code, { ... })
end
local function input(keys)
	vim.rpcrequest(child, "nvim_input", keys)
	vim.wait(100)
end
local function check(code)
	assert(
		vim.wait(2500, function()
			return lua(code)
		end, 20),
		code
	)
end
local ok, err = pcall(function()
	lua(
		[=[
    vim.opt.rtp:prepend(...)
    require("codex_cli").setup({chat={history=false}})
    for _, case in ipairs({
      { "markdown", { "```lua", "local x = 1", "```" }, "lua" },
      { "html", { '<script type="application/json">{"x":1}</script>' }, "json" },
    }) do
      local available, loaded = pcall(vim.treesitter.language.add, case[1])
      if available and loaded then
      local b = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(b, 0, -1, false, case[2])
      local parser = vim.treesitter.get_parser(b, case[1])
      parser:parse(true)
      assert(parser:children()[case[3]], "missing injection: " .. case[3])
      end
    end
    vim.o.columns, vim.o.lines = 120, 40
    local chat = require("codex_cli.chat")
    chat.setup({ history = false })
    chat.open()
    local s = chat._ui.session
    s.messages = { { role = "Codex", text = string.rep("코드 설명입니다.\n", 60) .. "```lua\nlocal x = 1\n```" } }
    chat.render()
  ]=],
		root
	)
	check('return vim.fn.mode() == "i"')
	input("<C-k>")
	check(
		'local u=require("codex_cli.chat")._ui; return vim.api.nvim_get_current_win()==u.output_win and vim.fn.mode()=="n"'
	)
	input("ggjj")
	check("return vim.api.nvim_win_get_cursor(0)[1] == 3")
	input("<C-j>")
	check(
		'local u=require("codex_cli.chat")._ui; return vim.api.nvim_get_current_win()==u.input_win and vim.fn.mode()=="i"'
	)
	input("draft")
	input("<C-j><C-h><C-l>")
	check('local u=require("codex_cli.chat")._ui; return vim.api.nvim_get_current_win()==u.input_win')
	lua('local u=require("codex_cli.chat")._ui; vim.api.nvim_set_current_win(u.previous_win)')
	check('local u=require("codex_cli.chat")._ui; return vim.api.nvim_get_current_win()==u.input_win')
	input("<C-k><C-w>w")
	check(
		'local u=require("codex_cli.chat")._ui; local w=vim.api.nvim_get_current_win(); return w==u.input_win or w==u.output_win'
	)
	input("<Esc>")
	check(
		'local u=require("codex_cli.chat")._ui; return not u.output_win and vim.api.nvim_get_current_win()==u.previous_win'
	)
	lua(
		'local c=require("codex_cli.chat"); c.open(); assert(vim.api.nvim_buf_get_lines(c._ui.input_buf,0,-1,false)[1]=="draft")'
	)
	input("<C-k>vj<C-j>")
	check(
		'local u=require("codex_cli.chat")._ui; return vim.api.nvim_get_current_win()==u.input_win and vim.fn.mode()=="i"'
	)
	input("<Esc>")
end)
vim.fn.jobstop(child)
assert(ok, err)
print(
	"PASS: clean config available language injections, Ctrl-K/J, j/k, focus containment, Esc, drafts, visual selection"
)
vim.cmd("qa!")
