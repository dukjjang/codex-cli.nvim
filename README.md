# codex-cli.nvim

Lightweight Neovim integration for Codex CLI via tmux `send-keys` or an embedded terminal UI.

- Prompt from Neovim, send to a running Codex CLI pane
- If no Codex CLI pane is found, open a local UI (popup or split)
- Visual selection adds file/line context
- Auto-reload buffers when Codex edits files

## Requirements

- Neovim >= 0.8
- Codex CLI available in PATH
- `tmux` (optional, for sending to an existing tmux pane)

## Installation (lazy.nvim)

```lua
{
  dir = "/Users/tedd/projects/codex-cli.nvim",
  name = "codex-cli.nvim",
  config = function()
    require("codex_cli").setup()
  end,
}
```

## Usage

- Normal mode: `<leader>aa` opens a prompt and sends:
  - `Context: <current-file>`
  - your prompt on the next line
- Visual mode: `<leader>av` opens a prompt and sends:
  - `Context: <current-file> lines <start>-<end>`
  - your prompt on the next line

Commands:

- `:CodexSend`
- `:CodexAsk`

## Configuration

```lua
require("codex_cli").setup({
  tmux = {
    command = "codex", -- match process name for pane detection
  },
  ui = {
    mode = "popup", -- "popup" or "split"
    command = "codex", -- command used to launch Codex CLI
    split = {
      direction = "right", -- "right" or "below"
      size = 0.4,
    },
    popup = {
      width = 0.8,
      height = 0.8,
      border = "rounded",
    },
  },
  keymaps = {
    enabled = true,
    ask = "<leader>aa",
    visual = "<leader>av",
  },
  command = "CodexSend",
  command_ask = "CodexAsk",
})
```

## Notes

- Pane detection searches the current tmux session and looks for a `codex` process
  in the pane's child process tree.
- If no tmux pane is found, Codex CLI starts in the configured UI mode.
- Buffers auto-reload on focus/enter/cursor hold via `checktime`.

## Troubleshooting

- **No codex pane found**: set `tmux.command` to match the process name you see in `ps`.
- **Not in tmux**: this plugin requires Neovim to run inside tmux.
