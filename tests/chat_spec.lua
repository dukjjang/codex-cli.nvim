vim.opt.rtp:prepend(vim.fn.getcwd())
vim.o.columns, vim.o.lines = 120, 40
require("codex_cli").setup({
	chat = { history = false, command = { "python3", vim.fn.getcwd() .. "/tests/fake_server.py" } },
})
local chat = require("codex_cli.chat")
local function wait(predicate)
	assert(vim.wait(5000, predicate, 10), "timed out")
end
local source = vim.api.nvim_get_current_buf()
vim.api.nvim_buf_set_lines(source, 0, -1, false, { "local hello = 'unsaved'", "print(hello)" })
chat.open(1, 2)
local ui, s = chat._ui, chat._ui.session
assert(s.context.text:find("unsaved", 1, true))
assert(s.context.label:find("1–2", 1, true))
chat.send("Explain this")
wait(function()
	return not s.busy
end)
assert(s.messages[2].text == '안녕하세요.\n```lua\nprint("hello")\n```', vim.inspect(s.messages))
assert(s.thread == "test-thread")
vim.api.nvim_buf_set_lines(s.input_buf, 0, -1, false, { "draft" })
chat.close()
assert(vim.api.nvim_get_current_buf() == source)
chat.open()
assert(chat._ui.session == s)
assert(vim.api.nvim_buf_get_lines(s.input_buf, 0, -1, false)[1] == "draft")
chat.mode()
local before = #s.messages
chat.send("Apply it")
assert(#s.messages == before, "must not edit with unsaved context")
vim.bo[source].modified = false
chat.send("Apply it")
wait(function()
	return not s.busy
end)
assert(#s.messages == before + 2)
chat.diff()
assert(vim.bo.filetype == "diff")
vim.cmd("close")
chat.open()
chat.send("STREAM")
wait(function()
	return s.received and s.busy and ui.loading_row == nil
end)
wait(function()
	return not s.busy
end)
wait(function()
	return ui.loading_timer == nil
end)
chat.send("HOLD")
wait(function()
	return s.turn ~= nil
end)
wait(function()
	return ui.loading_timer ~= nil and ui.loading_row ~= nil
end)
local loading_ns = vim.api.nvim_create_namespace("codex_chat_loading")
local function loading_text()
	return vim.inspect(vim.api.nvim_buf_get_extmarks(ui.output_buf, loading_ns, 0, -1, { details = true }))
end
assert(loading_text():find("답변을 준비하고 있어요", 1, true))
local tick = vim.api.nvim_buf_get_changedtick(ui.output_buf)
local previous = loading_text()
wait(function()
	return loading_text() ~= previous
end)
assert(vim.api.nvim_buf_get_changedtick(ui.output_buf) == tick, "spinner must not rewrite the transcript")
chat.close()
assert(ui.loading_timer == nil and s.busy)
chat.open()
wait(function()
	return ui.loading_timer ~= nil
end)
chat.cancel()
wait(function()
	return not s.busy
end)
assert(s.status == "중단됨")
wait(function()
	return ui.loading_timer == nil
end)
assert(#vim.api.nvim_buf_get_extmarks(ui.output_buf, loading_ns, 0, -1, {}) == 0)
s.rpc:stop()
wait(function()
	return not s.rpc.job
end)
chat.send("Reconnect and continue")
wait(function()
	return not s.busy
end)
assert(s.thread == "test-thread" and s.attached)
chat.new()
assert(s.thread == nil and #s.messages == 0 and s.mode == "ask")
for _, size in ipairs({ { 80, 24 }, { 30, 16 }, { 180, 55 } }) do
	vim.o.columns, vim.o.lines = size[1], size[2]
	chat.resize()
end
chat.close()
s.rpc:stop()
print("PASS: streaming, context, drafts, follow-up, apply protection, diff, interrupt, reset, resize")
vim.cmd("qa!")
