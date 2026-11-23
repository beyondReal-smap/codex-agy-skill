#!/usr/bin/env bash
# codex / agy(Antigravity CLI) 비대화형 호출 래퍼
# - 두 CLI의 플래그 차이(샌드박스·세션 이어가기·출력 형식)를 하나의 인터페이스로 통일
# - 실행 산출물(prompt/reply/log/meta)을 실행별 폴더에 남겨 Claude가 파일로 재확인할 수 있게 함
set -euo pipefail

usage() {
  cat <<'EOF'
사용법: run.sh <codex|agy> [옵션] [-f 프롬프트파일 | 프롬프트 텍스트...]

옵션:
  -w            쓰기 허용 (기본: 읽기 전용)
  -C DIR        작업 디렉토리 (기본: 현재 디렉토리)
  -m MODEL      모델 지정 (기본: 각 CLI 설정값)
  -e EFFORT     추론 강도 (codex: low|medium|high|xhigh, agy: low|medium|high|xhigh|max)
  -r ID         이전 세션 이어가기 (codex session id / agy conversation id)
  -s SCHEMA     최종 응답 JSON Schema 파일 (구조화 출력)
  -o DIR        산출물 폴더 (기본: <작업디렉토리>/.claude/scratch/agent-runs/<시각>-<agent>-<pid>)
  -t SECONDS    타임아웃 초 (기본: 1800)
  -n NAME       산출물 폴더 이름 접미사 (식별용)
  -G            호출 맥락 헤더(재귀 금지 등) 생략
  -h            도움말

프롬프트는 -f 파일 > 인자 > stdin 순으로 읽습니다.
EOF
}

AGENT="${1:-}"
case "$AGENT" in
  codex|agy) shift ;;
  -h|--help|"") usage; exit 0 ;;
  *) echo "❌ 알 수 없는 에이전트: $AGENT (codex 또는 agy)" >&2; usage >&2; exit 2 ;;
esac

MODE=ro; CWD="$PWD"; MODEL=""; EFFORT=""; RESUME=""; SCHEMA=""; OUT_DIR=""
TIMEOUT=1800; PROMPT_FILE=""; NAME=""; GUARD=1
while getopts ":wC:m:e:r:s:o:t:f:n:Gh" opt; do
  case $opt in
    w) MODE=rw ;;
    C) CWD=$OPTARG ;;
    m) MODEL=$OPTARG ;;
    e) EFFORT=$OPTARG ;;
    r) RESUME=$OPTARG ;;
    s) SCHEMA=$OPTARG ;;
    o) OUT_DIR=$OPTARG ;;
    t) TIMEOUT=$OPTARG ;;
    f) PROMPT_FILE=$OPTARG ;;
    n) NAME=$OPTARG ;;
    G) GUARD=0 ;;
    h) usage; exit 0 ;;
    \?) echo "❌ 알 수 없는 옵션: -$OPTARG" >&2; exit 2 ;;
    :) echo "❌ -$OPTARG 옵션에 값이 필요합니다" >&2; exit 2 ;;
  esac
done
shift $((OPTIND - 1))

command -v "$AGENT" >/dev/null || { echo "❌ $AGENT CLI가 설치되어 있지 않습니다" >&2; exit 127; }
TIMEOUT_BIN=$(command -v timeout || command -v gtimeout || true)
[ -n "$TIMEOUT_BIN" ] || { echo "❌ timeout 명령이 없습니다 (brew install coreutils)" >&2; exit 127; }
case "$TIMEOUT" in ''|*[!0-9]*) echo "❌ -t 는 초 단위 정수여야 합니다: $TIMEOUT" >&2; exit 2 ;; esac

CWD=$(cd "$CWD" && pwd)
if [ -n "$SCHEMA" ]; then
  [ -f "$SCHEMA" ] || { echo "❌ 스키마 파일 없음: $SCHEMA" >&2; exit 2; }
  SCHEMA=$(cd "$(dirname "$SCHEMA")" && pwd)/$(basename "$SCHEMA")
fi

# ── 프롬프트 수집 ──
if [ -n "$PROMPT_FILE" ]; then
  [ -f "$PROMPT_FILE" ] || { echo "❌ 프롬프트 파일 없음: $PROMPT_FILE" >&2; exit 2; }
  BODY=$(cat "$PROMPT_FILE")
elif [ $# -gt 0 ]; then
  BODY="$*"
elif [ ! -t 0 ]; then
  BODY=$(cat)
else
  echo "❌ 프롬프트가 비어 있습니다" >&2; usage >&2; exit 2
fi
[ -n "${BODY//[[:space:]]/}" ] || { echo "❌ 프롬프트가 비어 있습니다" >&2; exit 2; }

if [ -z "$OUT_DIR" ]; then
  OUT_DIR="$CWD/.claude/scratch/agent-runs/$(date +%Y%m%d-%H%M%S)-$AGENT${NAME:+-$NAME}-$$"
fi
mkdir -p "$OUT_DIR"
OUT_DIR=$(cd "$OUT_DIR" && pwd)
PROMPT_PATH="$OUT_DIR/prompt.md"; REPLY="$OUT_DIR/reply.md"; LOG="$OUT_DIR/log.txt"; META="$OUT_DIR/meta.json"

# ── 호출 맥락 헤더 (새 세션에만 추가; 이어가기는 이미 맥락을 알고 있음) ──
if [ "$MODE" = rw ]; then
  PERM="쓰기 허용 — 작업 디렉토리($CWD) 안에서만 파일을 수정하세요. git commit/push, 파일 삭제, 배포 명령은 실행하지 마세요."
else
  PERM="읽기 전용 — 파일을 생성·수정·삭제하지 마세요. 분석·검토·제안만 하세요."
fi
{
  if [ "$GUARD" = 1 ] && [ -z "$RESUME" ]; then
    cat <<EOF
[호출 맥락]
당신은 Claude Code(오케스트레이터)가 비대화형으로 호출한 하위 에이전트입니다.
- claude / codex / agy CLI를 다시 호출하지 마세요 (재귀 호출 금지).
- 사용자에게 되물을 수 없습니다. 모호한 부분은 합리적 가정을 명시하고 진행하세요.
- 실행 권한: $PERM
- 최종 응답은 결론을 먼저 쓰고, 근거는 \`파일경로:라인\` 형식으로, 변경한 파일이 있으면 목록으로 끝내세요.

---

EOF
  fi
  printf '%s\n' "$BODY"
} > "$PROMPT_PATH"

# ── CLI별 명령 구성 ──
SESSION=""; STATUS=""
START=$(date +%s)
set +e
if [ "$AGENT" = codex ]; then
  SANDBOX=$([ "$MODE" = rw ] && echo workspace-write || echo read-only)
  if [ -n "$RESUME" ]; then
    # resume 은 -s/-C 를 받지 않으므로 설정 오버라이드와 cd 로 대체
    CMD=(codex exec resume "$RESUME" -c "sandbox_mode=$SANDBOX")
  else
    CMD=(codex exec -C "$CWD" -s "$SANDBOX")
  fi
  CMD+=(--skip-git-repo-check -o "$REPLY")
  [ -n "$MODEL" ] && CMD+=(-m "$MODEL")
  [ -n "$EFFORT" ] && CMD+=(-c "model_reasoning_effort=$EFFORT")
  [ -n "$SCHEMA" ] && CMD+=(--output-schema "$SCHEMA")
  CMD+=(-)
  (cd "$CWD" && "$TIMEOUT_BIN" "$TIMEOUT" "${CMD[@]}" < "$PROMPT_PATH") > "$LOG" 2>&1
  RC=$?
  SESSION=$(grep -m1 -i '^session id:' "$LOG" | awk '{print $NF}' || true)
  [ -z "$SESSION" ] && SESSION="$RESUME"
  STATUS=$([ $RC -eq 0 ] && echo SUCCESS || echo FAILED)
  [ -f "$REPLY" ] || : > "$REPLY"
else
  CMD=(agy --output-format json --print-timeout "${TIMEOUT}s")
  # agy -p 기본 동작은 파일 쓰기·셸 실행을 묻지 않고 수행 → 읽기 전용은 plan 모드로 강제
  [ "$MODE" = ro ] && CMD+=(--mode plan)
  [ -n "$RESUME" ] && CMD+=(--conversation "$RESUME")
  [ -n "$MODEL" ] && CMD+=(--model "$MODEL")
  [ -n "$EFFORT" ] && CMD+=(--effort "$EFFORT")
  [ -n "$SCHEMA" ] && CMD+=(--json-schema "$SCHEMA")
  # -p 는 바로 뒤 토큰을 프롬프트로 삼으므로 '=' 로 붙여 마지막에 둔다
  CMD+=("--print=$(cat "$PROMPT_PATH")")
  RAW="$OUT_DIR/raw.json"
  (cd "$CWD" && "$TIMEOUT_BIN" $((TIMEOUT + 60)) "${CMD[@]}") > "$RAW" 2> "$LOG"
  RC=$?
  # JSON 응답 파싱 — 형식이 깨졌으면 실패로 처리(원본은 raw.json 에 보존)
  PARSED=$(python3 - "$RAW" "$REPLY" <<'PY'
import json, sys
raw_path, reply_path = sys.argv[1], sys.argv[2]
try:
    data = json.load(open(raw_path, encoding="utf-8"))
except (json.JSONDecodeError, OSError) as e:
    print(f"PARSE_ERROR\t\t{e}")
    sys.exit(0)
resp = data.get("response")
if not isinstance(resp, str):
    resp = json.dumps(resp, ensure_ascii=False, indent=2)
open(reply_path, "w", encoding="utf-8").write(resp)
print(f"{data.get('status', 'UNKNOWN')}\t{data.get('conversation_id', '')}\t")
PY
)
  IFS=$'\t' read -r STATUS SESSION PERR <<< "$PARSED"
  [ "$STATUS" = PARSE_ERROR ] && echo "JSON 파싱 실패: $PERR" >> "$LOG"
  [ -f "$REPLY" ] || : > "$REPLY"
  [ $RC -eq 0 ] && [ "$STATUS" != SUCCESS ] && RC=1
fi
set -e
DURATION=$(( $(date +%s) - START ))
[ $RC -eq 124 ] && STATUS=TIMEOUT

M_AGENT=$AGENT M_MODE=$MODE M_STATUS=$STATUS M_RC=$RC M_SESSION=$SESSION M_RESUME=$RESUME \
M_MODEL=$MODEL M_EFFORT=$EFFORT M_CWD=$CWD M_DURATION=$DURATION M_OUT=$OUT_DIR \
python3 - "$META" <<'PY'
import json, os, sys
e = os.environ
json.dump({
    "agent": e["M_AGENT"], "mode": e["M_MODE"], "status": e["M_STATUS"],
    "exit_code": int(e["M_RC"]), "session_id": e["M_SESSION"] or None,
    "resumed_from": e["M_RESUME"] or None, "model": e["M_MODEL"] or None,
    "effort": e["M_EFFORT"] or None, "cwd": e["M_CWD"],
    "duration_sec": int(e["M_DURATION"]), "out_dir": e["M_OUT"],
}, open(sys.argv[1], "w", encoding="utf-8"), ensure_ascii=False, indent=2)
PY

# ── 결과 출력 ──
ICON=$([ $RC -eq 0 ] && echo "✅" || echo "❌")
echo "$ICON agent=$AGENT mode=$MODE status=$STATUS rc=$RC session=$SESSION duration=${DURATION}s"
echo "📁 $OUT_DIR"
echo "──── reply ────"
LINES=$(wc -l < "$REPLY" | tr -d ' ')
if [ "$LINES" -gt 200 ]; then
  head -n 200 "$REPLY"
  echo "… (총 ${LINES}줄 — 전체는 $REPLY)"
else
  cat "$REPLY"
  # codex 응답은 끝 줄바꿈이 없어 다음 출력과 붙으므로 보정
  [ -s "$REPLY" ] && [ -n "$(tail -c1 "$REPLY")" ] && echo
fi
if [ $RC -ne 0 ]; then
  echo "──── log (마지막 30줄) ────"
  tail -n 30 "$LOG"
fi
exit $RC
