local tmux = require("codex_cli.tmux")
local terminal = require("codex_cli.terminal")
local util = require("codex_cli.util")

local M = {}

local function format_context_line(start_line, end_line)
  local file_path = vim.api.nvim_buf_get_name(0)
  if file_path == "" then
    file_path = "[No Name]"
  else
    file_path = vim.fn.fnamemodify(file_path, ":.")
  end

  return string.format("Context: %s lines %d-%d", file_path, start_line, end_line)
end

local function format_context_cursor()
  local file_path = vim.api.nvim_buf_get_name(0)
  if file_path == "" then
    file_path = "[No Name]"
  else
    file_path = vim.fn.fnamemodify(file_path, ":.")
  end

  return string.format("Context: %s", file_path)
end

local function ask_with_prompt(prefix)
  vim.ui.input({ prompt = "Codex: " }, function(input)
    if not input or input == "" then
      return
    end

    local text = prefix and (prefix .. "\n" .. input) or input
    local pane_id = nil
    if tmux.available() then
      pane_id = tmux.find_codex_pane()
    end

    if pane_id then
      tmux.send_to_pane(pane_id, text)
      return
    end

    terminal.send_to_terminal(text)
  end)
end

function M.ask_basic()
  ask_with_prompt(format_context_cursor())
end

local function resolve_visual_range()
  local mode = vim.fn.mode()
  local start_pos
  local end_pos

  if mode:find("[vV]") then
    start_pos = vim.fn.getpos("v")
    end_pos = vim.fn.getpos(".")
  else
    start_pos = vim.fn.getpos("'<")
    end_pos = vim.fn.getpos("'>")
  end

  if start_pos[2] == 0 or end_pos[2] == 0 then
    return nil, nil
  end

  local start_line = math.min(start_pos[2], end_pos[2])
  local end_line = math.max(start_pos[2], end_pos[2])
  return start_line, end_line
end

function M.ask_visual()
  local start_line, end_line = resolve_visual_range()
  if not start_line or not end_line then
    vim.defer_fn(function()
      local deferred_start, deferred_end = resolve_visual_range()
      if not deferred_start or not deferred_end then
        util.notify_err("No visual selection detected")
        return
      end
      local prefix = format_context_line(deferred_start, deferred_end)
      ask_with_prompt(prefix)
    end, 0)
    return
  end

  local prefix = format_context_line(start_line, end_line)
  ask_with_prompt(prefix)
end

return M
