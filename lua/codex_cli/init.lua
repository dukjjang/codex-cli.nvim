local actions = require("codex_cli.actions")
local autoread = require("codex_cli.autoread")
local commands = require("codex_cli.commands")
local config = require("codex_cli.config")
local keymaps = require("codex_cli.keymaps")
local terminal = require("codex_cli.terminal")

local M = {}

function M.setup(opts)
  config.set(opts or {})

  commands.setup()
  keymaps.setup()
  autoread.setup()
  terminal.setup_autoinsert()
end

M._ask_basic = actions.ask_basic
M._ask_visual = actions.ask_visual

return M
