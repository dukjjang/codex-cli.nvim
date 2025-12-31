local M = {}

function M.setup()
  vim.opt.autoread = true
  local group = vim.api.nvim_create_augroup("codex_cli_autoread", { clear = true })
  vim.api.nvim_create_autocmd({ "FocusGained", "BufEnter", "CursorHold" }, {
    group = group,
    command = "checktime",
  })
end

return M
