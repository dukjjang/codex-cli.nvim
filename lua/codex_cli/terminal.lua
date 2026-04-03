local overlay = require("codex_cli.overlay")
local session = require("codex_cli.session")

local M = {}

function M.send_to_terminal(text)
  local backend = session.resolve()
  local result = backend.send(text)
  if not result then
    return false
  end
  return true
end

function M.toggle_terminal()
  if overlay.is_open() then
    overlay.close()
    return
  end

  local backend = session.resolve()
  overlay.open({
    capture = backend.capture,
    on_submit = function(prompt)
      local result = backend.send(prompt)
      if not result then
        return
      end
      overlay.start_turn({
        baseline = result.baseline,
        sent_text = prompt,
      })
    end,
  })
end

function M.setup_autoinsert()
end

return M
