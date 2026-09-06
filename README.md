# codex-cli.nvim

직접 코딩하다 막히면, Neovim 안에서 Codex에게 질문하세요.
얇은 테두리와 중성 색상의 반투명 대화창에 답변이 스트리밍되고, 창을 닫고 코딩한 뒤 같은 대화를 이어갈 수 있습니다.

## 설치

Neovim 0.11 이상과 `codex app-server`를 지원하는 Codex CLI가 필요합니다.
Codex CLI는 [공식 설치 안내](https://developers.openai.com/codex/cli/)에 따라 설치하고,
각 컴퓨터에서 먼저 `codex login`을 실행하세요. 기존 ChatGPT 로그인으로 사용할 수 있습니다.
이 플러그인은 추가 Neovim 플러그인이나 tmux 없이 동작합니다.

### lazy.nvim

아래 설정을 플러그인 목록에 추가하면 됩니다. 개인 디렉터리나 별도 설정 파일은 필요하지 않습니다.

```lua
{
  "dukjjang/codex-cli.nvim",
  config = function()
    require("codex_cli").setup()
  end,
}
```

기본 키는 `<leader>aa`입니다. `vim.g.mapleader = " "`를 설정했다면 `Space → a → a`로 엽니다.
설치 후 `:checkhealth codex_cli`로 실행 환경을 확인할 수 있습니다.

### Neovim 기본 패키지로 설치

Unix 계열의 기본 데이터 경로를 사용하는 경우:

```sh
git clone https://github.com/dukjjang/codex-cli.nvim.git \
  "${XDG_DATA_HOME:-$HOME/.local/share}/nvim/site/pack/plugins/start/codex-cli.nvim"
```

`init.lua`에 다음을 추가하세요.

```lua
require("codex_cli").setup()
```

### 선택 설정

`setup()`만 호출해도 아래 기본값으로 동작합니다.

```lua
require("codex_cli").setup({
  chat = {
    command = { "codex", "app-server" }, -- PATH 밖에 있으면 실행 파일의 절대 경로 사용
    border = "single",  -- "rounded", "double", "none"도 사용 가능
    blend = 10,         -- 답변창 투명도 (0 = 불투명)
    input_blend = 6,     -- 입력창은 조금 더 선명하게
    backdrop_blend = 24, -- 뒤쪽 코드가 비치는 정도
    width = 0.76,        -- 화면 너비 비율, 최대 110열
    history = true,      -- 프로젝트별 최근 대화 복원
  },
})
```

Neovim 0.11.4와 0.12.5에서 테스트합니다. 실제 Codex 연결은 macOS의 CLI 0.153.4에서 검증했습니다.

## 사용 흐름

1. 코딩하다 `<leader>aa`로 질문 창을 엽니다. Visual로 코드를 선택한 뒤 눌러도 됩니다.
2. 질문을 입력하고 `Enter` 또는 `Ctrl-S`로 전송합니다.
3. 전송하면 스피너·준비 상태·경과 시간이 나타나고, 답변이 도착하면 본문으로 이어집니다. 답변은 생성되는 대로 나타납니다. `Ctrl-K`로 답변 창에 올라가 `j/k`로 읽거나 코드를 선택·복사하세요. `Ctrl-J`로 입력창에 돌아옵니다.
4. 같은 입력창에 후속 질문을 입력합니다. `Esc`로 창을 닫으면 원래 코드로 돌아갑니다.
5. 직접 수정하고 다시 열면 최신 버퍼 내용을 질문에 함께 전달합니다.
6. 구현을 맡기고 싶으면 파일을 저장한 뒤 `Ctrl-G`로 **적용** 모드를 선택하고 요청합니다.
7. `<leader>ad` 또는 대화창의 `gd`로 마지막 요청의 diff를 확인합니다.

기본 **질문** 모드는 읽기 전용 샌드박스와 설명·힌트 중심 지시를 사용합니다.
**적용** 모드는 프로젝트에 쓰기를 허용합니다. 프로젝트의 수정한 버퍼가 남아 있으면 전송을 막습니다.
Codex가 별도 승인을 요구하면 Neovim의 선택 UI로 확인합니다.
변경 내역은 **적용 후 확인용**입니다. diff 창에서 승인해야 쓰는 방식은 아닙니다.

## 키와 명령

| 키 | 동작 |
|---|---|
| `<leader>aa` | 현재 코드 또는 선택 영역을 가지고 질문 |
| `<leader>at` | 대화창 열기/닫기 |
| `<leader>an` | 새 대화 |
| `<leader>ad` | 마지막 변경 내역 |
| `Enter` / `Ctrl-S` | 입력창에서 전송 |
| `Alt-Enter` | 입력창에서 줄바꿈 |
| `Ctrl-O` | 입력창에서 Normal 모드로 전환하여 여러 줄 편집 |
| `Ctrl-K` | 답변창으로 이동, Normal 모드에서 `j/k`로 읽기 |
| `Ctrl-J` | 입력창으로 이동하여 바로 입력 |
| `Tab` | 답변/입력창 이동 |
| `Ctrl-G` | 질문/적용 모드 전환 |
| `Ctrl-C` | 진행 중인 응답 중단 |
| `Esc` | 대화를 유지하고 코드로 돌아가기 |
| `gd` | 대화창 Normal 모드에서 diff 보기 |

`:CodexAsk 질문`, `:'<,'>CodexAsk 질문`, `:CodexToggle`, `:CodexNew`,
`:CodexMode`, `:CodexStop`, `:CodexDiff` 명령을 사용할 수 있습니다.
`:CodexSend`는 `:CodexAsk`의 별칭입니다. `:CodexTerminal`은 기존 터미널을 엽니다.
키 설정은 `keymaps = { ask = "...", visual = "...", toggle = "..." }`,
전체 비활성화는 `keymaps = false`로 설정합니다.

## 대화와 컨텍스트

- Git 프로젝트 루트별로 대화를 나눕니다. Git 밖에서는 Neovim의 현재 작업 디렉터리를 사용합니다.
- 커서 앞뒤 최대 100줄, 또는 선택한 최대 400줄을 보냅니다. 코드 본문은 최대 40,000바이트입니다.
- 파일 경로, 줄 번호, 저장 전 버퍼 내용, 해당 범위의 진단 메시지를 함께 보냅니다.
- Visual 선택은 줄 단위로 확장됩니다. 입력 전 창 제목에 첨부 범위를 표시합니다.
- 팝업이 열린 동안 일반 편집창으로 포커스가 빠지지 않습니다. `Ctrl-H/L`은 팝업 안에서 무시합니다. 승인용 추가 대화창은 사용할 수 있습니다.
- 창을 닫아도 응답 생성은 계속됩니다. 입력 초안은 현재 Neovim 세션에서 유지됩니다.
- 최근 대화와 thread ID는 `stdpath("state")/codex-cli/`에 저장됩니다. 다시 시작하면 복원합니다.
- `history = false`는 이 플러그인의 로컬 기록 저장·복원을 끕니다. Codex 자체 기록 설정과는 별개입니다.
- 저장된 대화를 불러올 수 없으면 `:CodexNew`로 새 대화를 시작하세요.
- 적용 중 파일 변경을 감지하면 팝업 뒤쪽의 열린 코드 버퍼도 갱신합니다. 입력창 포커스와 질문 초안은 유지됩니다. 사용자의 미저장 변경은 덮어쓰지 않습니다.
- 대화창 투명도는 Neovim의 `winblend`를 사용합니다. 터미널 바깥 데스크톱의 투명도는 터미널 설정을 따릅니다.

## 연결 구조

기본 연결은 [Codex App Server](https://developers.openai.com/codex/app-server/)의 stdio JSON-RPC입니다.
터미널 화면을 캡처하지 않고 메시지 이벤트를 직접 표시합니다.
최초 응답까지 걸리는 시간은 모델과 연결 상태에 따라 달라집니다.

기존 tmux/터미널 연결을 사용하려면 `setup({ backend = "terminal" })`로 설정하세요.
이 경우 기존 `tmux`, `split`, `overlay`, `command_*` 설정을 사용할 수 있습니다.

## 검증

Neovim과 Python 3가 있으면 실행할 수 있습니다. 테스트는 임시 XDG 디렉터리를 사용하므로
개인 nvim 설정·로그인·API 키·네트워크 없이 실행됩니다.

```sh
bash tests/run.sh
```

스트리밍과 로딩 UI, 실제 키 입력과 포커스 제한, 대화 복원, 미저장 버퍼 보호,
적용 중 배경 코드 갱신과 atomic save, diff, 중단, 재연결, 창 크기 변경을 검증합니다.
GitHub Actions에서도 Neovim 0.11.4와 0.12.5로 실행합니다.

## 참고

- tmux에서 이미 실행 중인 Codex와 대화를 공유하지 않습니다. Neovim이 별도 app-server 대화를 엽니다.
- 대화 기록은 컴퓨터에 로컬로 저장됩니다. 플러그인을 다른 컴퓨터에 설치해도 이전 대화가 자동 동기화되지는 않습니다.
- Neovim 0.12와 구형 `nvim-treesitter`를 함께 사용할 때는 로드된 구형 query directive를 호환 처리합니다.
- 터미널 안의 코드에 실제 blur를 적용하는 기능은 없습니다. 투명도와 dim으로 가독성을 조절합니다.
- 개발용 로컬 checkout을 쓰려면 lazy.nvim 설정에 `dir = "/path/to/codex-cli.nvim"`을 추가하면 됩니다.
