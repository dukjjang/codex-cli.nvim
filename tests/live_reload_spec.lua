-- Exercise real Insert mode while another process changes the background file.
local root, tmp = vim.fn.getcwd(), vim.fn.tempname()
vim.fn.mkdir(tmp, "p")
local path = tmp .. "/example.txt"
vim.fn.writefile({ "before", "second line" }, path)
local child = vim.fn.jobstart({ vim.v.progpath, "--embed", "--headless", "-u", "NONE", "-i", "NONE" }, { rpc = true })
local function lua(code, ...)
	return vim.rpcrequest(child, "nvim_exec_lua", code, { ... })
end
local function check(code)
	assert(
		vim.wait(4000, function()
			return lua(code)
		end, 20),
		code
	)
end
local ok, err = pcall(function()
	lua(
		[=[
    local root, tmp, path = ...
    vim.opt.rtp:prepend(root)
    vim.cmd.cd(tmp)
    vim.cmd.edit(path)
    vim.g.reload_test_source = vim.api.nvim_get_current_buf()
    vim.bo.autoread = false
    vim.o.columns, vim.o.lines = 120, 40
    require("codex_cli").setup({chat={history=false,command={"python3",root.."/tests/fake_server.py"}}})
    local c=require("codex_cli.chat")
    c.open(); c.mode(); c.send("HOLD")
  ]=],
		root,
		tmp,
		path
	)
	check('return vim.fn.mode()=="i" and require("codex_cli.chat")._ui.session.turn ~= nil')
	vim.rpcrequest(child, "nvim_input", "my next question")
	vim.fn.writefile({ "changed during response", "second line", "new line" }, path)
	check('return vim.api.nvim_buf_get_lines(vim.g.reload_test_source,0,1,false)[1]=="changed during response"')
	lua([=[
    local u=require("codex_cli.chat")._ui
    assert(u.session.busy and u.output_win)
    assert(vim.api.nvim_get_current_win()==u.input_win and vim.fn.mode()=="i")
    assert(vim.api.nvim_buf_get_lines(u.input_buf,0,-1,false)[1]=="my next question")
    assert(not vim.bo[vim.g.reload_test_source].modified)
    assert(not vim.bo[vim.g.reload_test_source].autoread)
  ]=])
	-- Atomic saves replace the inode; polling must continue to follow the path.
	vim.fn.writefile({ "atomic replacement" }, path .. ".tmp")
	assert(vim.uv.fs_rename(path .. ".tmp", path))
	check('return vim.api.nvim_buf_get_lines(vim.g.reload_test_source,0,1,false)[1]=="atomic replacement"')
	lua('vim.api.nvim_buf_set_lines(vim.g.reload_test_source,0,-1,false,{"unsaved user work"})')
	vim.fn.writefile({ "must not overwrite unsaved work" }, path)
	vim.wait(600)
	lua('assert(vim.api.nvim_buf_get_lines(vim.g.reload_test_source,0,1,false)[1]=="unsaved user work")')
	lua('require("codex_cli.chat").cancel()')
	check('return not require("codex_cli.chat")._ui.session.busy')
	lua([=[
    local c=require("codex_cli.chat")
    assert(c._ui.session.reload==nil)
    assert(vim.api.nvim_buf_get_lines(vim.g.reload_test_source,0,1,false)[1]=="unsaved user work")
    c.close(); c._ui.session.rpc:stop()
  ]=])
end)
vim.fn.jobstop(child)
vim.fn.delete(tmp, "rf")
assert(ok, err)
print(
	"PASS: live background reload during Insert + active turn, focus/draft preservation, atomic saves, unsaved protection, cleanup"
)
vim.cmd("qa!")
