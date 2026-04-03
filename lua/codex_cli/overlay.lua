local config = require("codex_cli.config")

local M = {}

local state = {
  active = false,
  backdrop_buf = nil,
  backdrop_win = nil,
  content_buf = nil,
  content_win = nil,
  input_buf = nil,
  input_win = nil,
  previous_win = nil,
  submit_handler = nil,
  capture_handler = nil,
  timer = nil,
  inflight = false,
  turns = {},
  last_snapshot = "",
  ns = vim.api.nvim_create_namespace("codex_cli_overlay"),
}

local diff_languages = {
  diff = true,
  patch = true,
}

local function is_valid_buf(bufnr)
  return bufnr and vim.api.nvim_buf_is_valid(bufnr)
end

local function is_valid_win(winid)
  return winid and vim.api.nvim_win_is_valid(winid)
end

local function editor_size()
  local height = vim.o.lines - vim.o.cmdheight
  if vim.o.laststatus > 0 then
    height = height - 1
  end
  return vim.o.columns, math.max(height, 1)
end

local function normalize_capture(text)
  if not text or text == "" then
    return ""
  end

  local normalized = text
  normalized = normalized:gsub("\r\n", "\n")
  normalized = normalized:gsub("\r", "")
  normalized = normalized:gsub("\27%[[0-?]*[ -/]*[@-~]", "")
  normalized = normalized:gsub("\27%].-\7", "")
  normalized = normalized:gsub("\27P.-\27\\", "")
  return normalized
end

local function get_delta(previous, current)
  if current == previous then
    return ""
  end

  local found = current:find(previous, 1, true)
  if found then
    return current:sub(found + #previous)
  end

  local overlap = 0
  local max_overlap = math.min(#previous, #current)
  for size = max_overlap, 1, -1 do
    if previous:sub(-size) == current:sub(1, size) then
      overlap = size
      break
    end
  end

  if overlap > 0 then
    return current:sub(overlap + 1)
  end

  return current
end

local function extract_turn_content(turn)
  if turn.echo_removed then
    return turn.raw
  end

  local sent_text = turn.sent_text or ""
  if sent_text == "" then
    turn.echo_removed = true
    return turn.raw
  end

  local idx = turn.raw:find(sent_text, 1, true)
  if idx then
    turn.echo_removed = true
    turn.raw = turn.raw:sub(idx + #sent_text)
    turn.raw = turn.raw:gsub("^\n+", "")
    return turn.raw
  end

  if #turn.raw <= #sent_text and sent_text:sub(1, #turn.raw) == turn.raw then
    return ""
  end

  if #turn.raw > (#sent_text + 200) then
    turn.echo_removed = true
    turn.raw = turn.raw:gsub("^\n+", "")
    return turn.raw
  end

  return ""
end

local function ensure_highlights()
  vim.api.nvim_set_hl(0, "CodexCliBackdrop", { bg = "#000000" })
  vim.api.nvim_set_hl(0, "CodexCliPanel", { bg = "NONE" })
  vim.api.nvim_set_hl(0, "CodexCliInput", { link = "NormalFloat" })
  vim.api.nvim_set_hl(0, "CodexCliInputBorder", { link = "FloatBorder" })
  vim.api.nvim_set_hl(0, "CodexCliInputTitle", { link = "FloatTitle" })
  vim.api.nvim_set_hl(0, "CodexCliResponse", { link = "Normal" })
  vim.api.nvim_set_hl(0, "CodexCliWaiting", { link = "Comment" })
  vim.api.nvim_set_hl(0, "CodexCliPrompt", { link = "Comment" })
end

local function start_markdown_highlight(bufnr)
  pcall(vim.treesitter.stop, bufnr)
  pcall(vim.treesitter.start, bufnr, "markdown")
end

local function apply_diff_highlights(bufnr, lines)
  local in_fence = false
  local fence_lang = nil

  for index, line in ipairs(lines) do
    local linenr = index - 1
    local lang = line:match("^```%s*([%w_+-]+)%s*$")
    if line:match("^```") then
      if in_fence then
        in_fence = false
        fence_lang = nil
      else
        in_fence = true
        fence_lang = lang and lang:lower() or ""
      end
    elseif in_fence and diff_languages[fence_lang] then
      if line:match("^%+[^+]") then
        vim.api.nvim_buf_add_highlight(bufnr, state.ns, "DiffAdd", linenr, 0, -1)
      elseif line:match("^%-%-[^-]") or line:match("^%-[^-]") then
        vim.api.nvim_buf_add_highlight(bufnr, state.ns, "DiffDelete", linenr, 0, -1)
      elseif line:match("^@@") or line:match("^diff%s") or line:match("^index%s") or line:match("^%+%+%+") then
        vim.api.nvim_buf_add_highlight(bufnr, state.ns, "DiffChange", linenr, 0, -1)
      end
    end
  end
end

local function clear_timer()
  if state.timer then
    vim.fn.timer_stop(state.timer)
    state.timer = nil
  end
end

local function focus_input()
  if not is_valid_win(state.input_win) then
    return
  end

  vim.api.nvim_set_current_win(state.input_win)
  vim.cmd("startinsert")
end

local function set_input_buffer()
  if not is_valid_buf(state.input_buf) then
    return
  end

  vim.bo[state.input_buf].modifiable = true
  vim.api.nvim_buf_set_lines(state.input_buf, 0, -1, false, { "" })
end

local function render()
  if not is_valid_buf(state.content_buf) then
    return
  end

  local lines = {}
  local highlights = {}

  for index, turn in ipairs(state.turns) do
    if index > 1 and #lines > 0 then
      table.insert(lines, "")
    end

    local content = turn.content or ""
    if content ~= "" then
      local start_line = #lines
      local turn_lines = vim.split(content, "\n", { plain = true })
      vim.list_extend(lines, turn_lines)
      table.insert(highlights, {
        group = "CodexCliResponse",
        first = start_line,
        last = #lines - 1,
      })
    end
  end

  if #lines == 0 then
    lines = { "Waiting for Codex response..." }
    highlights = {
      { group = "CodexCliWaiting", first = 0, last = 0 },
    }
  end

  vim.bo[state.content_buf].modifiable = true
  vim.api.nvim_buf_set_lines(state.content_buf, 0, -1, false, lines)
  vim.api.nvim_buf_clear_namespace(state.content_buf, state.ns, 0, -1)

  for _, item in ipairs(highlights) do
    for line = item.first, item.last do
      vim.api.nvim_buf_add_highlight(state.content_buf, state.ns, item.group, line, 0, -1)
    end
  end

  apply_diff_highlights(state.content_buf, lines)

  vim.bo[state.content_buf].modifiable = false
  start_markdown_highlight(state.content_buf)

  if is_valid_win(state.content_win) then
    local last_line = math.max(#lines, 1)
    pcall(vim.api.nvim_win_set_cursor, state.content_win, { last_line, 0 })
  end
end

local function layout()
  local width, height = editor_size()
  local overlay_cfg = config.get().overlay
  local input_height = math.max(overlay_cfg.input_height, 1)
  local max_width = math.max(width - 2, 20)
  local content_width = math.min(math.max(math.floor(width * 0.9), 72), max_width)
  local content_height = math.max(math.floor(height * 0.68), 10)
  local total_height = content_height + input_height + 1

  if total_height >= height then
    content_height = math.max(height - input_height - 3, 8)
    total_height = content_height + input_height + 1
  end

  local col = math.max(math.floor((width - content_width) / 2), 0)
  local row = math.max(math.floor((height - total_height) / 2), 0)

  if is_valid_buf(state.backdrop_buf) then
    vim.bo[state.backdrop_buf].modifiable = true
    vim.api.nvim_buf_set_lines(state.backdrop_buf, 0, -1, false, vim.fn["repeat"]({ "" }, height))
    vim.bo[state.backdrop_buf].modifiable = false
  end

  if is_valid_win(state.backdrop_win) then
    vim.api.nvim_win_set_config(state.backdrop_win, {
      relative = "editor",
      row = 0,
      col = 0,
      width = width,
      height = height,
    })
  end

  if is_valid_win(state.content_win) then
    vim.api.nvim_win_set_config(state.content_win, {
      relative = "editor",
      row = row,
      col = col,
      width = content_width,
      height = content_height,
    })
  end

  if is_valid_win(state.input_win) then
    vim.api.nvim_win_set_config(state.input_win, {
      relative = "editor",
      row = row + content_height + 1,
      col = col,
      width = content_width,
      height = input_height,
    })
  end
end

local function close_window(winid)
  if is_valid_win(winid) then
    pcall(vim.api.nvim_win_close, winid, true)
  end
end

local function reset_state()
  state.active = false
  state.backdrop_buf = nil
  state.backdrop_win = nil
  state.content_buf = nil
  state.content_win = nil
  state.input_buf = nil
  state.input_win = nil
  state.previous_win = nil
  state.submit_handler = nil
  state.capture_handler = nil
  state.turns = {}
  state.last_snapshot = ""
  state.inflight = false
end

function M.close()
  clear_timer()

  local previous_win = state.previous_win
  close_window(state.input_win)
  close_window(state.content_win)
  close_window(state.backdrop_win)
  reset_state()

  if is_valid_win(previous_win) then
    vim.api.nvim_set_current_win(previous_win)
  end
end

local function map_close_keys(bufnr)
  local opts = { buffer = bufnr, silent = true, nowait = true }

  vim.keymap.set("n", "<Esc>", M.close, opts)
  vim.keymap.set("n", "q", M.close, opts)
  vim.keymap.set("i", "<Esc>", function()
    vim.schedule(M.close)
  end, opts)
end

local function ensure_windows()
  if state.active and is_valid_win(state.backdrop_win) and is_valid_win(state.content_win) and is_valid_win(state.input_win) then
    layout()
    return
  end

  ensure_highlights()

  state.previous_win = vim.api.nvim_get_current_win()

  state.backdrop_buf = vim.api.nvim_create_buf(false, true)
  state.content_buf = vim.api.nvim_create_buf(false, true)
  state.input_buf = vim.api.nvim_create_buf(false, true)

  local width, height = editor_size()
  local overlay_cfg = config.get().overlay

  vim.bo[state.backdrop_buf].bufhidden = "wipe"
  vim.bo[state.content_buf].bufhidden = "wipe"
  vim.bo[state.input_buf].bufhidden = "wipe"
  vim.bo[state.content_buf].filetype = "markdown"
  vim.bo[state.input_buf].buftype = "prompt"
  vim.bo[state.input_buf].filetype = "codex-cli-input"

  vim.bo[state.backdrop_buf].modifiable = true
  vim.api.nvim_buf_set_lines(state.backdrop_buf, 0, -1, false, vim.fn["repeat"]({ "" }, height))
  vim.bo[state.backdrop_buf].modifiable = false

  state.backdrop_win = vim.api.nvim_open_win(state.backdrop_buf, false, {
    relative = "editor",
    row = 0,
    col = 0,
    width = width,
    height = height,
    style = "minimal",
    focusable = false,
    zindex = 30,
  })

  state.content_win = vim.api.nvim_open_win(state.content_buf, false, {
    relative = "editor",
    row = 1,
    col = 1,
    width = 10,
    height = 10,
    style = "minimal",
    zindex = 40,
  })

  state.input_win = vim.api.nvim_open_win(state.input_buf, true, {
    relative = "editor",
    row = 1,
    col = 1,
    width = 10,
    height = overlay_cfg.input_height,
    style = "minimal",
    border = "single",
    zindex = 41,
    title = " Ask Codex ",
    title_pos = "left",
  })

  vim.api.nvim_set_option_value("winblend", overlay_cfg.backdrop_blend, { win = state.backdrop_win })
  vim.api.nvim_set_option_value("winhl", "Normal:CodexCliBackdrop,NormalFloat:CodexCliBackdrop", { win = state.backdrop_win })
  vim.api.nvim_set_option_value("winblend", 12, { win = state.content_win })
  vim.api.nvim_set_option_value("winblend", 0, { win = state.input_win })
  vim.api.nvim_set_option_value("winhl", "Normal:CodexCliPanel,NormalFloat:CodexCliPanel", { win = state.content_win })
  vim.api.nvim_set_option_value(
    "winhl",
    "Normal:CodexCliInput,NormalFloat:CodexCliInput,FloatBorder:CodexCliInputBorder,FloatTitle:CodexCliInputTitle",
    { win = state.input_win }
  )

  for _, winid in ipairs({ state.content_win, state.input_win }) do
    vim.wo[winid].wrap = true
    vim.wo[winid].linebreak = true
    vim.wo[winid].breakindent = false
    vim.wo[winid].showbreak = ""
    vim.wo[winid].number = false
    vim.wo[winid].relativenumber = false
    vim.wo[winid].signcolumn = "no"
    vim.wo[winid].foldcolumn = "0"
    vim.wo[winid].cursorline = false
    vim.wo[winid].cursorcolumn = false
    vim.wo[winid].spell = false
    vim.wo[winid].list = false
    vim.wo[winid].colorcolumn = ""
    vim.wo[winid].statuscolumn = ""
    vim.wo[winid].conceallevel = 0
    vim.wo[winid].winbar = ""
  end

  vim.wo[state.content_win].winfixbuf = true
  vim.wo[state.input_win].winfixbuf = true

  vim.fn.prompt_setprompt(state.input_buf, "> ")
  vim.fn.prompt_setcallback(state.input_buf, function(text)
    local prompt = vim.trim(text or "")
    set_input_buffer()
    if prompt ~= "" and state.submit_handler then
      state.submit_handler(prompt)
    end
    vim.schedule(focus_input)
  end)

  map_close_keys(state.content_buf)
  map_close_keys(state.input_buf)

  state.active = true
  layout()
  render()
  set_input_buffer()
  focus_input()
end

local function poll_once()
  if not state.active or not state.capture_handler or state.inflight then
    return
  end

  state.inflight = true

  state.capture_handler(function(snapshot)
    state.inflight = false
    if not state.active or not snapshot then
      return
    end

    snapshot = normalize_capture(snapshot)
    local previous = state.last_snapshot or ""
    local delta = get_delta(previous, snapshot)
    state.last_snapshot = snapshot

    if delta == "" then
      return
    end

    local turn = state.turns[#state.turns]
    if not turn then
      return
    end

    turn.raw = (turn.raw or "") .. delta
    turn.content = extract_turn_content(turn)
    render()
  end)
end

local function ensure_timer()
  if state.timer then
    return
  end

  state.timer = vim.fn.timer_start(config.get().overlay.poll_interval, function()
    vim.schedule(poll_once)
  end, { ["repeat"] = -1 })
end

function M.open(opts)
  if not config.get().overlay.enabled then
    return
  end

  state.submit_handler = opts.on_submit
  state.capture_handler = opts.capture
  ensure_windows()
  ensure_timer()
end

function M.start_turn(opts)
  if not state.active then
    return
  end

  state.last_snapshot = normalize_capture(opts.baseline or "")
  table.insert(state.turns, {
    sent_text = normalize_capture(opts.sent_text or ""),
    raw = "",
    content = "",
    echo_removed = false,
  })
  render()
end

function M.is_open()
  return state.active
end

return M
