# codex-agy — Claude Code가 Codex·Antigravity를 부리는 스킬

[Claude Code](https://claude.com/claude-code)가 **OpenAI Codex CLI**(`codex`)와 **Google Antigravity CLI**(`agy`)를 하위 에이전트로 호출·제어하게 해 주는 스킬입니다.

> **English summary** — A Claude Code skill that lets Claude orchestrate `codex` (OpenAI Codex CLI) and `agy` (Google Antigravity CLI) as sub-agents: second opinions, cross-model code review, parallel research, delegated implementation and multi-turn session resume, all through one safe wrapper (`run.sh`) that defaults to read-only.

```
"codex한테 이 PR 리뷰 받아보고, gemini 의견도 같이 들어봐"
   └─ Claude ─┬─ run.sh codex -f brief.md  ─→ GPT 리뷰
              └─ run.sh agy   -f brief.md  ─→ Gemini 리뷰
                 → Claude가 두 답을 직접 검증·비교해 보고
```

## ✨ 기능

| 기능 | 설명 |
|------|------|
| 🔒 **읽기 전용 기본값** | codex는 OS 샌드박스(`read-only`), agy는 `--mode plan`을 자동 적용 |
| 🔁 **세션 이어가기** | `-r <session>` 하나로 codex `resume` / agy `--conversation` 통일 |
| ⚡ **병렬 세컨드 오피니언** | 같은 브리프를 두 모델에 동시에 보내고 Claude가 교차 검증 |
| 🛠️ **구현 위임** | `-w`로 쓰기 허용, git worktree 격리 패턴 안내 |
| 🧾 **실행 기록 보존** | 실행마다 `prompt.md` · `reply.md` · `log.txt` · `meta.json` 저장 |
| 🧱 **재귀 방지 헤더** | 하위 에이전트가 claude/codex/agy를 다시 호출하거나 커밋·푸시·삭제하지 않도록 프롬프트에 자동 삽입 |
| 📐 **구조화 출력** | `-s schema.json`으로 JSON 응답 강제 |
| ⏱️ **타임아웃** | `-t`(기본 30분), 초과 시 `status=TIMEOUT` |

## 📋 요구사항

- Claude Code
- `codex` 또는 `agy` 중 하나 이상 — 설치·로그인 완료 상태
  - Codex CLI: `codex login`
  - Antigravity CLI: `agy` (최초 실행 시 로그인)
- `python3`, `timeout` (macOS: `brew install coreutils`)
- macOS / Linux (bash 3.2+)

## 🚀 설치

### 방법 1. 플러그인 마켓플레이스 (권장)

Claude Code 안에서:

```
/plugin marketplace add beyondReal-smap/codex-agy-skill
/plugin install codex-agy@codex-agy-skill
```

또는 터미널에서:

```bash
claude plugin marketplace add beyondReal-smap/codex-agy-skill
claude plugin install codex-agy@codex-agy-skill
```

업데이트: `claude plugin update codex-agy@codex-agy-skill`

### 방법 2. 설치 스크립트 (한 줄)

```bash
curl -fsSL https://raw.githubusercontent.com/beyondReal-smap/codex-agy-skill/main/install.sh | bash
```

`~/.claude/skills/codex-agy`에 복사됩니다. 기존 설치본이 있으면 지우지 않고 `codex-agy.bak-<시각>`으로 백업합니다. 설치 위치는 `CLAUDE_SKILLS_DIR` 환경변수로 바꿀 수 있습니다.

### 방법 3. 직접 clone

```bash
git clone https://github.com/beyondReal-smap/codex-agy-skill.git
cd codex-agy-skill
./install.sh          # 복사
./install.sh --link   # 심볼릭 링크 (git pull 만으로 업데이트)
```

설치 후 Claude Code를 재시작하세요.

## 💬 사용법

Claude Code에 평소처럼 말하면 스킬이 자동으로 선택됩니다.

- "codex한테 `src/auth.ts` 경쟁 조건 검토 받아봐"
- "이 설계안, gemini 의견도 들어보고 비교해줘"
- "이 버그 원인을 codex랑 agy한테 병렬로 물어보고 교차 검증해줘"
- "이 리팩토링은 codex한테 worktree에서 구현 맡겨"

### 래퍼 직접 호출

```bash
RUN=~/.claude/skills/codex-agy/scripts/run.sh

$RUN codex "이 저장소의 에러 처리 패턴을 요약해줘"          # 읽기 전용
$RUN agy -f brief.md -n design-review                       # 프롬프트 파일
$RUN codex -w -C ../repo-feature -e high -f brief.md        # 쓰기 허용
$RUN codex -r 01a205b9-... "2번 지적의 수정안을 코드로"      # 세션 이어가기
echo "질문" | $RUN agy -m gemini-3.8-flash-low              # stdin + 모델 지정
```

| 옵션 | 의미 |
|------|------|
| `-w` | 쓰기 허용 (기본: 읽기 전용) |
| `-C DIR` | 작업 디렉토리 |
| `-m MODEL` | 모델 (기본: 각 CLI 설정값, agy는 `agy models`의 ID) |
| `-e EFFORT` | 추론 강도 (`low`·`medium`·`high`·`xhigh`, agy는 `max`도 가능) |
| `-r ID` | 세션 이어가기 |
| `-s SCHEMA` | 최종 응답 JSON Schema 파일 |
| `-o DIR` / `-n NAME` | 산출물 폴더 / 폴더 이름 접미사 |
| `-t SEC` | 타임아웃 (기본 1800초) |
| `-G` | 호출 맥락 헤더 생략 |

**출력 예시**

```
✅ agent=codex mode=ro status=SUCCESS rc=0 session=01a205bf-63db-... duration=11s
📁 /path/to/project/.claude/scratch/agent-runs/20261123-101500-codex-4242
──── reply ────
(응답 본문)
```

산출물 기본 위치는 `<작업디렉토리>/.claude/scratch/agent-runs/`입니다. git에 섞이지 않게 하려면 `.gitignore`(또는 전역 gitignore)에 `.claude/scratch/`를 추가하세요.

## 🛡️ 안전 설계

| 위험 | 대응 |
|------|------|
| agy `-p` 기본 모드는 파일 쓰기·셸 실행을 **확인 없이** 수행 | 읽기 전용일 때 `--mode plan` 강제 |
| agy `--sandbox`는 작업 디렉토리 쓰기를 막지 못함 | 읽기 전용 수단으로 사용하지 않음 |
| 하위 에이전트의 재귀 호출·커밋·푸시·삭제 | 프롬프트 헤더로 금지, 쓰기 범위는 작업 디렉토리로 한정 |
| 다른 모델의 답을 그대로 믿는 문제 | 스킬 절차에 "인용된 `파일:라인`을 직접 확인·`git diff` 검토" 단계 포함 |

> ⚠️ codex의 읽기 전용은 OS 샌드박스가 실제로 막아 주지만, agy의 plan 모드는 **프롬프트 수준 제약**입니다. 확실한 차단이 필요한 작업에는 codex를 쓰세요.

## 📁 구조

```
codex-agy-skill/
├── .claude-plugin/
│   ├── marketplace.json        # /plugin marketplace add 용
│   └── plugin.json
├── skills/codex-agy/
│   ├── SKILL.md                # Claude가 읽는 지침 (언제·어떻게·안전 규칙)
│   ├── scripts/run.sh          # codex·agy 통합 래퍼
│   └── references/cli-reference.md   # CLI 플래그 대응표·실측 함정
├── install.sh
└── README.md
```

## 🔧 호환성

`codex-cli 0.170.0`, `agy 1.5.13`에서 확인했습니다. CLI 업데이트로 플래그가 바뀌면 [`cli-reference.md`](skills/codex-agy/references/cli-reference.md)의 대응표를 보고 `run.sh`를 수정하세요. 이슈·PR 환영합니다.

## 📄 라이선스

[MIT](LICENSE)
