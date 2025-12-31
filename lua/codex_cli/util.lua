local M = {}

function M.notify_err(message)
  vim.notify(message, vim.log.levels.ERROR, { title = "codex-cli.nvim" })
end

function M.normalize_ratio(value)
  if type(value) ~= "number" then
    return 0.5
  end
  return math.min(0.95, math.max(0.2, value))
end

function M.is_job_running(job_id)
  if not job_id or job_id <= 0 then
    return false
  end
  local result = vim.fn.jobwait({ job_id }, 0)[1]
  return result == -1
end

return M
