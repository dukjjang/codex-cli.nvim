local M = {}

local default_config = {
  tmux = {
    command = "codex",
  },
  keymaps = {
    enabled = true,
    ask = "<leader>aa",
    visual = "<leader>av",
  },
  command = "CodexSend",
  command_ask = "CodexAsk",
}

local config = vim.deepcopy(default_config)

local function notify_err(message)
  vim.notify(message, vim.log.levels.ERROR, { title = "codex-cli.nvim" })
end

local function tmux_available()
  if vim.fn.executable("tmux") ~= 1 then
    notify_err("tmux executable not found in PATH")
    return false
  end

  if not vim.env.TMUX or vim.env.TMUX == "" then
    notify_err("Not running inside a tmux session")
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

local function find_codex_pane()
  local match_cmd = config.tmux.command

  local current_pane = vim.fn.system("tmux display-message -p '#{pane_id}'")
  if vim.v.shell_error ~= 0 then
    notify_err("Failed to get current tmux pane")
    return nil
  end
  current_pane = vim.trim(current_pane)

  local result = vim.fn.system("tmux list-panes -s -F '#{pane_id}:#{pane_pid}'")
  if vim.v.shell_error ~= 0 then
    notify_err("Failed to list tmux panes")
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

  notify_err("No codex pane found in current tmux session")
  return nil
end

local function send_text_l(pane_id, text)
  local escaped = vim.fn.shellescape(text)
  local cmd = string.format("tmux send-keys -t %s -l %s", pane_id, escaped)
  vim.fn.system(cmd)
  return vim.v.shell_error == 0
end

local function send_to_pane(pane_id, text)
  if not send_text_l(pane_id, text) then
    notify_err("Failed to send keys to tmux pane")
    return false
  end

  vim.defer_fn(function()
    if not send_text_l(pane_id, "\r") then
      notify_err("Failed to send Enter to tmux pane")
    end
  end, 50)

  return true
end

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

    local pane_id = find_codex_pane()
    if not pane_id then
      return
    end

    local text = prefix and (prefix .. "\n" .. input) or input
    send_to_pane(pane_id, text)
  end)
end

local function ask_basic()
  if not tmux_available() then
    return
  end

  ask_with_prompt(format_context_cursor())
end

local function ask_visual()
  if not tmux_available() then
    return
  end

  local start_pos = vim.fn.getpos("'<")
  local end_pos = vim.fn.getpos("'>")
  if start_pos[2] == 0 or end_pos[2] == 0 then
    notify_err("No visual selection detected")
    return
  end
  local start_line = math.min(start_pos[2], end_pos[2])
  local end_line = math.max(start_pos[2], end_pos[2])

  local prefix = format_context_line(start_line, end_line)
  ask_with_prompt(prefix)
end

local function setup_commands()
  if config.command and config.command ~= "" then
    pcall(vim.api.nvim_del_user_command, config.command)
    vim.api.nvim_create_user_command(config.command, function()
      ask_basic()
    end, {})
  end

  if config.command_ask and config.command_ask ~= "" then
    pcall(vim.api.nvim_del_user_command, config.command_ask)
    vim.api.nvim_create_user_command(config.command_ask, function()
      ask_basic()
    end, {})
  end
end

local function register_which_key()
  local ok, which_key = pcall(require, "which-key")
  if not ok then
    return false
  end

  which_key.add({ { "<leader>a", group = "Codex" } })
  if config.keymaps.ask and config.keymaps.ask ~= "" then
    which_key.add({ mode = "n", { config.keymaps.ask, desc = "Codex Ask" } })
  end
  if config.keymaps.visual and config.keymaps.visual ~= "" then
    which_key.add({ mode = "v", { config.keymaps.visual, desc = "Codex Ask (visual)" } })
  end

  return true
end

local function setup_keymaps()
  if not config.keymaps.enabled then
    return
  end

  if config.keymaps.ask and config.keymaps.ask ~= "" then
    vim.keymap.set("n", config.keymaps.ask, ask_basic, { desc = "Codex Ask", silent = true })
  end

  if config.keymaps.visual and config.keymaps.visual ~= "" then
    vim.keymap.set("v", config.keymaps.visual, ask_visual, { desc = "Codex Ask (visual)", silent = true })
  end

  if not register_which_key() then
    local group = vim.api.nvim_create_augroup("codex_cli_which_key", { clear = true })
    vim.api.nvim_create_autocmd("User", {
      group = group,
      pattern = "VeryLazy",
      callback = function()
        register_which_key()
      end,
    })
  end
end

local function setup_autoread()
  vim.opt.autoread = true
  local group = vim.api.nvim_create_augroup("codex_cli_autoread", { clear = true })
  vim.api.nvim_create_autocmd({ "FocusGained", "BufEnter", "CursorHold" }, {
    group = group,
    command = "checktime",
  })
end

function M.setup(opts)
  config = vim.tbl_deep_extend("force", vim.deepcopy(default_config), opts or {})

  setup_commands()
  setup_keymaps()
  setup_autoread()
end

M._ask_basic = ask_basic
M._ask_visual = ask_visual

return M
