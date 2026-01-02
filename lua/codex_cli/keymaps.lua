local actions = require("codex_cli.actions")
local config = require("codex_cli.config")
local terminal = require("codex_cli.terminal")

local M = {}

local function register_which_key()
  local ok, which_key = pcall(require, "which-key")
  if not ok then
    return false
  end

  local cfg = config.get()
  which_key.add({ { "<leader>a", group = "Codex" } })
  if cfg.keymaps.ask and cfg.keymaps.ask ~= "" then
    which_key.add({ mode = "n", { cfg.keymaps.ask, desc = "Codex Ask" } })
    which_key.add({ mode = "v", { cfg.keymaps.ask, desc = "Codex Ask" } })
  end
  if cfg.keymaps.visual and cfg.keymaps.visual ~= "" and cfg.keymaps.visual ~= cfg.keymaps.ask then
    which_key.add({ mode = "v", { cfg.keymaps.visual, desc = "Codex Ask (visual)" } })
  end
  if cfg.keymaps.toggle and cfg.keymaps.toggle ~= "" then
    which_key.add({ mode = "n", { cfg.keymaps.toggle, desc = "Codex Toggle" } })
  end

  return true
end

function M.setup()
  local cfg = config.get()
  if not cfg.keymaps.enabled then
    return
  end

  if cfg.keymaps.ask and cfg.keymaps.ask ~= "" then
    vim.keymap.set({ "n", "v" }, cfg.keymaps.ask, actions.ask, { desc = "Codex Ask", silent = true })
  end
  if cfg.keymaps.visual and cfg.keymaps.visual ~= "" and cfg.keymaps.visual ~= cfg.keymaps.ask then
    vim.keymap.set("v", cfg.keymaps.visual, actions.ask, { desc = "Codex Ask (visual)", silent = true })
  end

  if cfg.keymaps.toggle and cfg.keymaps.toggle ~= "" then
    vim.keymap.set("n", cfg.keymaps.toggle, terminal.toggle_terminal, { desc = "Codex Toggle", silent = true })
  end

  if not register_which_key() then
    local group = vim.api.nvim_create_augroup("codex_cli_which_key", { clear = true })
    vim.api.nvim_create_autocmd("User", {
      group = group,
      pattern = "VeryLazy",
      callback = function()
        register_which_key()
      end,
    })
  end
end

return M
