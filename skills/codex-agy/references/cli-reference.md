# CLI 원시 플래그 레퍼런스

> 2026-11-23 실측 기준: `codex-cli 0.170.0`, `agy 1.5.13`.
> CLI 업데이트 후 동작이 이상하면 `codex exec --help`, `codex exec resume --help`, `agy --help` 로 재확인하세요.

## 래퍼 옵션 → 실제 플래그

| 래퍼 | codex (새 세션) | codex (resume) | agy |
|------|-----------------|----------------|-----|
| 읽기 전용(기본) | `-s read-only` | `-c sandbox_mode=read-only` | `--mode plan` |
| `-w` | `-s workspace-write` | `-c sandbox_mode=workspace-write` | (모드 지정 없음 = 전부 자동 승인) |
| `-C DIR` | `-C DIR` + cd | cd 만 (resume 은 `-C` 미지원) | cd |
| `-m` | `-m MODEL` | `-m MODEL` | `--model MODEL` |
| `-e` | `-c model_reasoning_effort=E` | 동일 | `--effort E` |
| `-r ID` | — | `codex exec resume ID` | `--conversation ID` |
| `-s SCHEMA` | `--output-schema FILE` | 동일 | `--json-schema FILE` |
| 응답 파일 | `-o reply.md` | 동일 | `--output-format json` → `.response` 추출 |
| 세션 ID | 로그의 `session id: ...` 줄 | 동일 | JSON `.conversation_id` |
| 타임아웃 | `timeout N` | 동일 | `--print-timeout Ns` + `timeout N+60` |
| 프롬프트 | stdin (`-`) | stdin (`-`) | `--print=<본문>` |

## 실측으로 확인한 함정

| 항목 | 내용 |
|------|------|
| agy `-p` 인자 | `-p` 는 **바로 다음 토큰을 프롬프트로** 삼음. `echo x \| agy -p --output-format json` 은 `--output-format` 을 프롬프트로 오인해 오류. 래퍼는 `--print=<본문>` 을 마지막에 둠 |
| agy 기본 권한 | `-p` 기본 모드에서 파일 생성·셸 명령이 **확인 없이 실행**됨 (`date > x.txt` 실행 확인) |
| agy plan 모드 | 파일 생성 요청 시 실제 파일은 만들지 않고 `~/.gemini/antigravity-cli/brain/<id>/implementation_plan.md` 에 계획만 작성 |
| agy `--sandbox` | 터미널 제한 모드지만 작업 디렉토리 내 `date > x.txt` 는 **실행됨** → 읽기 전용 수단으로 부적합 |
| codex resume 샌드박스 | `-c sandbox_mode=read-only` 로 이전 세션(workspace-write)도 읽기 전용으로 전환됨 (로그 `sandbox: read-only` 확인) |
| codex 비 git 디렉토리 | `--skip-git-repo-check` 없으면 실행 거부 → 래퍼가 항상 추가 |
| zsh 단어 분리 | `f="--mode plan"; agy $f` 는 zsh 에서 한 토큰으로 전달돼 오류. 래퍼는 bash 배열 사용 |

## 기본 설정 위치

| CLI | 설정 | 전역 지침 |
|-----|------|-----------|
| codex | `~/.codex/config.toml` (`model`, `model_reasoning_effort`) | `config.toml` 의 `developer_instructions` 또는 `~/.codex/AGENTS.md` |
| agy | `~/.gemini/antigravity-cli/settings.json` (`model`) | `~/.gemini/GEMINI.md` |

`-m`/`-e` 를 생략하면 위 설정의 기본값이 쓰입니다.
모델 목록: `agy models` — agy `--model` 에는 목록 왼쪽의 ID(예: `gemini-3.8-flash-low`)를 사용합니다.

## 기타 유용한 하위 명령

- `codex review` — 현재 저장소 변경분 코드 리뷰 전용 명령 (`codex review "보안 관점 중심으로"`). 래퍼 미경유, 읽기 위주.
- `codex exec --worktree` — codex 가 관리형 git worktree 를 직접 만들어 작업.
- `agy --add-dir DIR` — 작업 공간에 디렉토리 추가.
- `agy agents` — 사용 가능한 agy 에이전트 목록 (`--agent` 로 지정).
