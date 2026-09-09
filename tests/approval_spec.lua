vim.opt.rtp:prepend(vim.fn.getcwd())
vim.o.columns, vim.o.lines = 120, 40
require("codex_cli").setup({
	chat = { history = false, command = { "python3", vim.fn.getcwd() .. "/tests/fake_server.py" } },
})
local chat = require("codex_cli.chat")
local function wait(predicate)
	assert(vim.wait(5000, predicate, 10), "approval flow timed out")
end
local pending, prompts, preview = nil, 0, nil
vim.ui.select = function(items, options, callback)
	assert(items[1] == "거절" and items[2] == "승인")
	assert(options.prompt:find("git ", 1, true))
	prompts = prompts + 1
	preview = options.prompt
	pending = callback
end
chat.open()
local s = chat._ui.session
chat.send("APPROVAL_CHECK")
wait(function() return not s.busy end)
assert(prompts == 0 and s.messages[#s.messages].text:find("blocked"), "질문 mode must deny without a prompt")
chat.mode()
for _, case in ipairs({
	{ request = "APPROVAL_CHECK", choice = "승인", outcome = "executed" },
	{ request = "APPROVAL_CHECK", choice = "거절", outcome = "blocked" },
	{ request = "APPROVAL_CHECK PUSH_CHECK", outcome = "blocked" },
	{ request = "APPROVAL_CHECK PUSH_CHECK", choice = "승인", outcome = "executed" },
}) do
	local before = prompts
	pending = nil
	chat.send(case.request)
	wait(function() return pending ~= nil end)
	assert(s.busy and prompts == before + 1, "every invocation must wait for a new approval")
	assert(s.messages[#s.messages].role == "승인 요청", "command must be shown before approval")
	pending(case.choice)
	wait(function() return not s.busy end)
	assert(s.messages[#s.messages].text:find(case.outcome, 1, true), vim.inspect(s.messages))
end
for _, choice in ipairs({ "승인", "거절" }) do
	local before = prompts
	pending = nil
	chat.send("APPROVAL_CHECK PUBLISH_CHECK")
	wait(function() return pending ~= nil end)
	assert(preview:find("커밋 메시지: feat: publish reviewed change", 1, true))
	assert(preview:find("Git 인덱스 쓰기", 1, true))
	assert(preview:find("푸시 대상: origin / main", 1, true))
	assert(preview:find('git add -- src/change.lua && git commit -m "feat: publish reviewed change" && git push origin HEAD:main', 1, true))
	assert(preview:find(s.cwd, 1, true), "approval must identify the repository")
	pending(choice)
	wait(function() return not s.busy end)
	assert(prompts == before + 1, "the combined execution must have one approval")
	assert(s.messages[#s.messages].text:find(choice == "승인" and "executed" or "blocked", 1, true))
end
chat.close()
s.rpc:stop()
print("PASS: ask denies, apply waits for user, allow executes once, reject/cancel blocks, separate push prompts again, combined commit/push previews message and approves once")
vim.cmd("qa!")
