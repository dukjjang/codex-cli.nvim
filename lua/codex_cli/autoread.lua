local M = {}

local watchers = {}

local function watch_file(bufnr)
  local filepath = vim.api.nvim_buf_get_name(bufnr)
  if filepath == "" or watchers[bufnr] then
    return
  end

  local handle = vim.loop.new_fs_event()
  if not handle then
    return
  end

  handle:start(filepath, {}, function(err, _, events)
    if err then
      return
    end
    if events.change or events.rename then
      vim.schedule(function()
        if vim.api.nvim_buf_is_valid(bufnr) then
          vim.api.nvim_buf_call(bufnr, function()
            vim.cmd("checktime")
          end)
        end
      end)
    end
  end)

  watchers[bufnr] = handle
end

local function unwatch_file(bufnr)
  local handle = watchers[bufnr]
  if handle then
    handle:stop()
    handle:close()
    watchers[bufnr] = nil
  end
end

function M.setup()
  vim.opt.autoread = true

  local group = vim.api.nvim_create_augroup("codex_cli_autoread", { clear = true })

  -- 기존 fallback
  vim.api.nvim_create_autocmd({ "FocusGained", "BufEnter", "CursorHold" }, {
    group = group,
    command = "checktime",
  })

  -- 파일 watcher 설정
  vim.api.nvim_create_autocmd("BufReadPost", {
    group = group,
    callback = function(args)
      watch_file(args.buf)
    end,
  })

  vim.api.nvim_create_autocmd("BufDelete", {
    group = group,
    callback = function(args)
      unwatch_file(args.buf)
    end,
  })

  -- 이미 열린 버퍼들 감시
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(bufnr) then
      watch_file(bufnr)
    end
  end
end

return M
