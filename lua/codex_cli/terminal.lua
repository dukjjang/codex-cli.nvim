local config = require("codex_cli.config")
local util = require("codex_cli.util")

local M = {}

local terminal_state = {
  bufnr = nil,
  winid = nil,
  job_id = nil,
}

local function open_split(bufnr)
  local cfg = config.get()
  local direction = cfg.split.direction
  local size_ratio = util.normalize_ratio(cfg.split.size)

  if direction == "below" then
    local height = math.floor(vim.o.lines * size_ratio)
    vim.cmd(string.format("botright %dsplit", height))
  else
    local width = math.floor(vim.o.columns * size_ratio)
    vim.cmd(string.format("botright %dvsplit", width))
  end

  local winid = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(winid, bufnr)

  return winid
end

local function ensure_window(bufnr)
  if terminal_state.winid and vim.api.nvim_win_is_valid(terminal_state.winid) then
    if vim.api.nvim_win_get_buf(terminal_state.winid) ~= bufnr then
      vim.api.nvim_win_set_buf(terminal_state.winid, bufnr)
    end
    return terminal_state.winid
  end

  terminal_state.winid = open_split(bufnr)
  return terminal_state.winid
end

local function ensure_terminal()
  -- 기존 터미널이 있고 실행 중이면 재사용
  if terminal_state.bufnr and vim.api.nvim_buf_is_valid(terminal_state.bufnr) then
    if terminal_state.job_id and util.is_job_running(terminal_state.job_id) then
      local winid = ensure_window(terminal_state.bufnr)
      if winid and vim.api.nvim_win_is_valid(winid) then
        vim.api.nvim_set_current_win(winid)
      end
      return terminal_state.bufnr, terminal_state.job_id, false -- false = 새로 생성 안함
    end
  end

  -- 새 터미널 생성
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_option(bufnr, "bufhidden", "hide")
  local winid = ensure_window(bufnr)

  if winid and vim.api.nvim_win_is_valid(winid) then
    vim.api.nvim_set_current_win(winid)
  end
  local cfg = config.get()
  local job_id = vim.fn.termopen(cfg.split.command, {
    on_exit = function()
      terminal_state.job_id = nil
    end,
  })

  terminal_state.bufnr = bufnr
  terminal_state.winid = winid
  terminal_state.job_id = job_id

  return bufnr, job_id, true -- true = 새로 생성됨
end

function M.send_to_terminal(text)
  local _, job_id, is_new = ensure_terminal()
  if not job_id or job_id <= 0 then
    util.notify_err("Failed to start Codex CLI terminal")
    return false
  end

  -- 새로 터미널을 열었으면 codex 초기화 대기
  local delay = is_new and 1000 or 0

  vim.defer_fn(function()
    vim.fn.chansend(job_id, text)
    vim.defer_fn(function()
      vim.fn.chansend(job_id, "\r")
      -- 터미널 모드로 진입
      vim.cmd("startinsert")
    end, 50)
  end, delay)

  return true
end

function M.toggle_terminal()
  -- 창이 열려있으면 닫기
  if terminal_state.winid and vim.api.nvim_win_is_valid(terminal_state.winid) then
    vim.api.nvim_win_close(terminal_state.winid, false)
    terminal_state.winid = nil
    return
  end

  -- 기존 터미널 버퍼가 있고 job이 실행 중이면 창만 다시 열기
  if terminal_state.bufnr and vim.api.nvim_buf_is_valid(terminal_state.bufnr) then
    if terminal_state.job_id and util.is_job_running(terminal_state.job_id) then
      local winid = ensure_window(terminal_state.bufnr)
      if winid and vim.api.nvim_win_is_valid(winid) then
        vim.api.nvim_set_current_win(winid)
        vim.cmd("startinsert")
      end
      return
    end
  end

  -- 터미널이 없으면 새로 생성
  local _, job_id = ensure_terminal()
  if not job_id or job_id <= 0 then
    util.notify_err("Failed to start Codex CLI terminal")
    return
  end
  vim.cmd("startinsert")
end

local function should_autoinsert_terminal()
  return terminal_state.bufnr
    and vim.api.nvim_get_current_buf() == terminal_state.bufnr
    and terminal_state.job_id
    and util.is_job_running(terminal_state.job_id)
end

function M.setup_autoinsert()
  local group = vim.api.nvim_create_augroup("codex_cli_terminal", { clear = true })
  vim.api.nvim_create_autocmd({ "BufEnter", "WinEnter" }, {
    group = group,
    callback = function()
      -- codex 터미널 버퍼인지 확인
      if should_autoinsert_terminal() then
        vim.cmd("startinsert")
      end
    end,
  })
end

return M
