local M = {}

local default_config = {
  tmux = {
    command = "codex",
  },
  split = {
    command = "codex",
    direction = "right", -- "right" or "below"
    size = 0.4, -- width/height ratio
  },
  keymaps = {
    enabled = true,
    ask = "<leader>aa",
    visual = "<leader>av",
    toggle = "<leader>at",
  },
  command = "CodexSend",
  command_ask = "CodexAsk",
  command_toggle = "CodexToggle",
}

local config = vim.deepcopy(default_config)

function M.get()
  return config
end

function M.set(opts)
  config = vim.tbl_deep_extend("force", vim.deepcopy(default_config), opts or {})
  return config
end

function M.defaults()
  return default_config
end

return M
