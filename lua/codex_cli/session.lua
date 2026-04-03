local config = require("codex_cli.config")
local tmux = require("codex_cli.tmux")
local util = require("codex_cli.util")

local M = {}

local local_state = {
  bufnr = nil,
  job_id = nil,
}

local function is_valid_buf(bufnr)
  return bufnr and vim.api.nvim_buf_is_valid(bufnr)
end

local function is_job_running(job_id)
  return job_id and util.is_job_running(job_id)
end

local function create_hidden_terminal()
  local prev_win = vim.api.nvim_get_current_win()
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.bo[bufnr].bufhidden = "hide"

  vim.cmd("silent keepalt botright 1split")
  local term_win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(term_win, bufnr)

  local job_id = vim.fn.termopen(config.get().split.command, {
    on_exit = function()
      local_state.job_id = nil
    end,
  })

  local_state.bufnr = bufnr
  local_state.job_id = job_id

  if vim.api.nvim_win_is_valid(prev_win) then
    vim.api.nvim_set_current_win(prev_win)
  end
  if vim.api.nvim_win_is_valid(term_win) then
    vim.api.nvim_win_close(term_win, false)
  end

  return bufnr, job_id, true
end

local function ensure_local_terminal()
  if is_valid_buf(local_state.bufnr) and is_job_running(local_state.job_id) then
    return local_state.bufnr, local_state.job_id, false
  end

  return create_hidden_terminal()
end

local function local_snapshot()
  if not is_valid_buf(local_state.bufnr) then
    return ""
  end

  local ok, lines = pcall(vim.api.nvim_buf_get_lines, local_state.bufnr, 0, -1, false)
  if not ok then
    return ""
  end

  return table.concat(lines, "\n")
end

local function make_tmux_backend(pane_id)
  return {
    kind = "tmux",
    id = pane_id,
    capture = function(callback)
      tmux.capture_pane_async(pane_id, config.get().overlay.capture_lines, callback)
    end,
    capture_sync = function()
      return tmux.capture_pane(pane_id, config.get().overlay.capture_lines) or ""
    end,
    send = function(text)
      local baseline = tmux.capture_pane(pane_id, config.get().overlay.capture_lines) or ""
      if not tmux.send_to_pane(pane_id, text) then
        return nil
      end
      return {
        baseline = baseline,
      }
    end,
  }
end

local function make_local_backend()
  return {
    kind = "local",
    id = "local",
    capture = function(callback)
      vim.schedule(function()
        callback(local_snapshot(), nil)
      end)
    end,
    capture_sync = function()
      return local_snapshot()
    end,
    send = function(text)
      local _, job_id, is_new = ensure_local_terminal()
      if not job_id or job_id <= 0 then
        return nil
      end

      local baseline = local_snapshot()
      local delay = is_new and 1000 or 0

      vim.defer_fn(function()
        if not is_job_running(job_id) then
          return
        end
        vim.fn.chansend(job_id, text)
        vim.defer_fn(function()
          if is_job_running(job_id) then
            vim.fn.chansend(job_id, "\r")
          end
        end, 50)
      end, delay)

      return {
        baseline = baseline,
      }
    end,
  }
end

function M.resolve(preferred_backend)
  if preferred_backend then
    return preferred_backend
  end

  if tmux.available() then
    local pane_id = tmux.find_codex_pane()
    if pane_id then
      return make_tmux_backend(pane_id)
    end
  end

  ensure_local_terminal()
  return make_local_backend()
end

return M
