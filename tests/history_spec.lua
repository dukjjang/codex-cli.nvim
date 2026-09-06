vim.opt.rtp:prepend(vim.fn.getcwd())
vim.o.columns, vim.o.lines = 120, 40
require("codex_cli").setup({ chat = { command = { "python3", vim.fn.getcwd() .. "/tests/fake_server.py" } } })
local chat = require("codex_cli.chat")
chat.open()
local s = chat._ui.session
if vim.env.CODEX_TEST_RESTORE == "1" then
	assert(s.thread == "test-thread" and #s.messages == 2, "history did not restore")
else
	chat.new()
end
chat.send("Persistence test")
assert(vim.wait(5000, function()
	return not s.busy
end, 10))
assert(s.status == "완료", vim.inspect(s.messages))
chat.close()
s.rpc:stop()
print("PASS: persisted history / resume")
vim.cmd("qa!")
