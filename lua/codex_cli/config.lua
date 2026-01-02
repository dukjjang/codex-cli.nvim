local util = require("codex_cli.util")

local M = {}

-- Defaults are normalized by normalize_opts().
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
    visual = "<leader>aa",
    toggle = "<leader>at",
  },
  command = "CodexSend",
  command_ask = "CodexAsk",
  command_toggle = "CodexToggle",
}

local config = vim.deepcopy(default_config)

local function ensure_table(value, name)
  if type(value) == "table" then
    return value
  end
  if value ~= nil then
    util.notify_warn_once(string.format("Invalid config for %s; using defaults.", name))
  end
  return {}
end

local function ensure_string(value, default, name)
  if type(value) == "string" and value ~= "" then
    return value
  end
  if value ~= nil then
    util.notify_warn_once(string.format("Invalid config for %s; using default.", name))
  end
  return default
end

local function ensure_string_allow_empty(value, default, name)
  if type(value) == "string" then
    return value
  end
  if value ~= nil then
    util.notify_warn_once(string.format("Invalid config for %s; using default.", name))
  end
  return default
end

local function ensure_bool(value, default, name)
  if type(value) == "boolean" then
    return value
  end
  if value ~= nil then
    util.notify_warn_once(string.format("Invalid config for %s; using default.", name))
  end
  return default
end

local function ensure_direction(value, default, name)
  if value == "right" or value == "below" then
    return value
  end
  if value ~= nil then
    util.notify_warn_once(string.format("Invalid config for %s; using default.", name))
  end
  return default
end

local function ensure_number(value, default, name)
  if type(value) == "number" then
    return value
  end
  if value ~= nil then
    util.notify_warn_once(string.format("Invalid config for %s; using default.", name))
  end
  return default
end

local function normalize_opts(opts)
  if opts == nil then
    return {}
  end
  if type(opts) ~= "table" then
    util.notify_warn_once("Invalid config root; expected table. Using defaults.")
    return {}
  end

  local clean = {}

  local tmux_opts = ensure_table(opts.tmux, "tmux")
  clean.tmux = {
    command = ensure_string(tmux_opts.command, default_config.tmux.command, "tmux.command"),
  }

  local split_opts = ensure_table(opts.split, "split")
  clean.split = {
    command = ensure_string(split_opts.command, default_config.split.command, "split.command"),
    direction = ensure_direction(split_opts.direction, default_config.split.direction, "split.direction"),
    size = ensure_number(split_opts.size, default_config.split.size, "split.size"),
  }

  local keymaps_opts = opts.keymaps
  if type(keymaps_opts) == "boolean" then
    keymaps_opts = { enabled = keymaps_opts }
  else
    keymaps_opts = ensure_table(keymaps_opts, "keymaps")
  end
  clean.keymaps = {
    enabled = ensure_bool(keymaps_opts.enabled, default_config.keymaps.enabled, "keymaps.enabled"),
    ask = ensure_string_allow_empty(keymaps_opts.ask, default_config.keymaps.ask, "keymaps.ask"),
    visual = ensure_string_allow_empty(keymaps_opts.visual, default_config.keymaps.visual, "keymaps.visual"),
    toggle = ensure_string_allow_empty(keymaps_opts.toggle, default_config.keymaps.toggle, "keymaps.toggle"),
  }

  clean.command = ensure_string_allow_empty(opts.command, default_config.command, "command")
  clean.command_ask = ensure_string_allow_empty(opts.command_ask, default_config.command_ask, "command_ask")
  clean.command_toggle = ensure_string_allow_empty(opts.command_toggle, default_config.command_toggle, "command_toggle")

  return clean
end

function M.get()
  return config
end

function M.set(opts)
  local normalized = normalize_opts(opts)
  config = vim.tbl_deep_extend("force", vim.deepcopy(default_config), normalized)
  return config
end

function M.defaults()
  return default_config
end

return M
