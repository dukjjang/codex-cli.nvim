vim.opt.rtp:prepend(vim.fn.getcwd())
vim.o.columns, vim.o.lines = 120, 40
require("codex_cli").setup({ chat = { mcp_auto_approve = { Argent = { "list-devices" } }, history = false, command = { "python3", vim.fn.getcwd() .. "/tests/fake_server.py" } } })
local chat = require("codex_cli.chat")
chat.open()
local s = chat._ui.session
local function wait(fn) assert(vim.wait(5000, fn, 10), "MCP response timed out") end
local pending, label
vim.ui.select = function(items, opts, callback) pending, label = callback, opts.prompt end
for _, case in ipairs({ {"승인", "accept"}, {"거절", "decline"}, {false, "cancel"} }) do
  pending = nil
  chat.send("MCP_CHECK")
  wait(function() return pending ~= nil end)
  assert(label:find("Argent", 1, true) and label:find("list_devices", 1, true))
  pending(case[1] or nil)
  wait(function() return not s.busy end)
  local result = vim.json.decode(s.messages[#s.messages].text)
  assert(result.action == case[2])
  if result.action == "accept" then assert(vim.deep_equal(result.content, vim.empty_dict())) end
end
pending = nil
chat.send("MCP_CHECK AUTO_APPROVE")
wait(function() return not s.busy end)
assert(pending == nil, "Configured list-devices must execute without an approval dialog")
assert(vim.json.decode(s.messages[#s.messages].text).action == "accept")
pending = nil
chat.send("MCP_CHECK AUTO_APPROVE FIELDS")
wait(function() return pending ~= nil end)
pending("거절")
wait(function() return not s.busy end)
assert(vim.json.decode(s.messages[#s.messages].text).action == "decline", "Form input must never be auto-approved")
chat.mode()
vim.ui.input = function(opts, callback) callback("2") end
vim.ui.select = function(items, opts, callback)
  if items[1] == "거절" then callback("승인")
  elseif opts.prompt:find("device",1,true) then callback(items[1])
  else callback(items[2]) end
end
chat.send("MCP_CHECK FIELDS")
wait(function() return not s.busy end)
local result = vim.json.decode(s.messages[#s.messages].text)
assert(result.action == "accept" and result.content.count == 2 and result.content.device == "simulator" and result.content.enabled == false)
-- A dialog accepted after cancellation must not authorize a stale request.
pending = nil
vim.ui.select = function(_, _, callback) pending = callback end
chat.send("MCP_CHECK")
wait(function() return pending ~= nil end)
chat.cancel()
wait(function() return not s.busy end)
pending("승인")
wait(function() return s.messages[#s.messages].text:find('cancel',1,true) ~= nil end)
chat.close()
s.rpc:stop()
print("PASS: MCP form approval, rejection, cancellation, typed inputs and stale approval")
vim.cmd("qa!")
