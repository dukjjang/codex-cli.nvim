local config = require("codex_cli.config")
local util = require("codex_cli.util")

local M = {}

function M.available()
  if vim.fn.executable("tmux") ~= 1 then
    return false
  end

  if not vim.env.TMUX or vim.env.TMUX == "" then
    return false
  end

  return true
end

local function get_child_pids(pid)
  local children = {}
  local result =
    vim.fn.system(string.format("ps -eo pid,ppid,comm 2>/dev/null | awk '$2 == %s {print $1}'", pid))
  for child_pid in result:gmatch("%d+") do
    table.insert(children, child_pid)
  end
  return children
end

local function has_codex_descendant(pid, match_cmd)
  local children = get_child_pids(pid)
  if #children == 0 then
    return false
  end

  for _, child_pid in ipairs(children) do
    local proc_name = vim.fn.system(string.format("ps -p %s -o comm= 2>/dev/null", child_pid))
    proc_name = vim.trim(proc_name)
    if proc_name:find(match_cmd, 1, true) then
      return true
    end

    local grandchildren = get_child_pids(child_pid)
    for _, gc_pid in ipairs(grandchildren) do
      local gc_name = vim.fn.system(string.format("ps -p %s -o comm= 2>/dev/null", gc_pid))
      gc_name = vim.trim(gc_name)
      if gc_name:find(match_cmd, 1, true) then
        return true
      end
    end
  end

  return false
end

function M.find_codex_pane()
  local match_cmd = config.get().tmux.command

  local current_pane = vim.fn.system("tmux display-message -p '#{pane_id}'")
  if vim.v.shell_error ~= 0 then
    return nil
  end
  current_pane = vim.trim(current_pane)

  local result = vim.fn.system("tmux list-panes -s -F '#{pane_id}:#{pane_pid}'")
  if vim.v.shell_error ~= 0 then
    return nil
  end

  for line in result:gmatch("[^\r\n]+") do
    local pane_id, pid = line:match("^(%%?%d+):(%d+)")
    if pane_id and pid and pane_id ~= current_pane then
      if has_codex_descendant(pid, match_cmd) then
        return pane_id
      end
    end
  end

  return nil
end

local function send_text_l(pane_id, text)
  local escaped = vim.fn.shellescape(text)
  local cmd = string.format("tmux send-keys -t %s -l %s", pane_id, escaped)
  vim.fn.system(cmd)
  return vim.v.shell_error == 0
end

function M.send_to_pane(pane_id, text)
  if not send_text_l(pane_id, text) then
    util.notify_err("Failed to send keys to tmux pane")
    return false
  end

  vim.defer_fn(function()
    if not send_text_l(pane_id, "\r") then
      util.notify_err("Failed to send Enter to tmux pane")
    end
  end, 50)

  return true
end

return M
