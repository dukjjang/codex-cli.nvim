local actions = require("codex_cli.actions")
local config = require("codex_cli.config")
local terminal = require("codex_cli.terminal")

local M = {}

function M.setup()
  local cfg = config.get()
  if cfg.command and cfg.command ~= "" then
    pcall(vim.api.nvim_del_user_command, cfg.command)
    vim.api.nvim_create_user_command(cfg.command, function()
      actions.ask_basic()
    end, {})
  end

  if cfg.command_ask and cfg.command_ask ~= "" then
    pcall(vim.api.nvim_del_user_command, cfg.command_ask)
    vim.api.nvim_create_user_command(cfg.command_ask, function()
      actions.ask_basic()
    end, {})
  end

  if cfg.command_toggle and cfg.command_toggle ~= "" then
    pcall(vim.api.nvim_del_user_command, cfg.command_toggle)
    vim.api.nvim_create_user_command(cfg.command_toggle, function()
      terminal.toggle_terminal()
    end, {})
  end
end

return M
