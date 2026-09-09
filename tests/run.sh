#!/usr/bin/env bash
set -eu
repo_root=$(cd "$(dirname "$0")/.." && pwd)
cd "$repo_root"
test_root=$(mktemp -d)
trap 'rm -rf "$test_root"' EXIT
export XDG_CONFIG_HOME="$test_root/config"
export XDG_DATA_HOME="$test_root/data"
export XDG_STATE_HOME="$test_root/state"
export XDG_CACHE_HOME="$test_root/cache"
nvim --headless -u NONE -i NONE -l tests/chat_spec.lua
nvim --headless -u NONE -i NONE -l tests/approval_spec.lua
nvim --headless -u NONE -i NONE -l tests/instructions_spec.lua
nvim --headless -u NONE -i NONE -l tests/editor_spec.lua
nvim --headless -u NONE -i NONE -l tests/live_reload_spec.lua
nvim --headless -u NONE -i NONE -l tests/history_spec.lua
CODEX_TEST_RESTORE=1 nvim --headless -u NONE -i NONE -l tests/history_spec.lua
nvim --headless -u NONE -i NONE -l tests/model_spec.lua
nvim --headless -u NONE -i NONE -l tests/skills_spec.lua
nvim --headless -u NONE -i NONE -l tests/tui_spec.lua
nvim --headless -u NONE -i NONE -l tests/completion_spec.lua
nvim --headless -u NONE -i NONE -l tests/prompt_history_spec.lua
