#!/usr/bin/env bash
# codex-agy 스킬 설치 스크립트
#   원격 설치:  curl -fsSL https://raw.githubusercontent.com/beyondReal-smap/codex-agy-skill/main/install.sh | bash
#   로컬 설치:  ./install.sh          (복사)
#               ./install.sh --link   (심볼릭 링크 — 저장소를 수정하면 바로 반영, 개발용)
# 설치 위치는 CLAUDE_SKILLS_DIR 로 바꿀 수 있습니다 (기본: ~/.claude/skills)
set -euo pipefail

REPO_URL="https://github.com/beyondReal-smap/codex-agy-skill.git"
SKILL=codex-agy
DEST_ROOT="${CLAUDE_SKILLS_DIR:-$HOME/.claude/skills}"
DEST="$DEST_ROOT/$SKILL"
MODE=copy

for arg in "$@"; do
  case "$arg" in
    --link) MODE=link ;;
    -h|--help) sed -n '2,7p' "$0"; exit 0 ;;
    *) echo "❌ 알 수 없는 옵션: $arg" >&2; exit 2 ;;
  esac
done

# 스크립트가 저장소 안에서 실행됐는지 판단 (curl | bash 이면 BASH_SOURCE 가 비어 있음)
SRC=""
SELF="${BASH_SOURCE[0]:-}"
if [ -n "$SELF" ] && [ -f "$SELF" ]; then
  HERE=$(cd "$(dirname "$SELF")" && pwd)
  [ -f "$HERE/skills/$SKILL/SKILL.md" ] && SRC="$HERE/skills/$SKILL"
fi

if [ -z "$SRC" ]; then
  [ "$MODE" = link ] && { echo "❌ --link 는 저장소를 clone 한 뒤 로컬에서만 사용할 수 있습니다" >&2; exit 2; }
  command -v git >/dev/null || { echo "❌ git 이 필요합니다" >&2; exit 127; }
  TMP=$(mktemp -d)
  trap 'rm -rf "$TMP"' EXIT
  echo "⬇️  $REPO_URL 내려받는 중..."
  git clone --depth 1 --quiet "$REPO_URL" "$TMP/repo"
  SRC="$TMP/repo/skills/$SKILL"
fi

mkdir -p "$DEST_ROOT"
# 기존 설치본은 지우지 않고 백업으로 옮김
if [ -e "$DEST" ] || [ -L "$DEST" ]; then
  BACKUP="$DEST.bak-$(date +%Y%m%d-%H%M%S)"
  mv "$DEST" "$BACKUP"
  echo "📦 기존 설치본 백업: $BACKUP"
fi

if [ "$MODE" = link ]; then
  ln -s "$SRC" "$DEST"
else
  cp -R "$SRC" "$DEST"
fi
chmod +x "$DEST/scripts/run.sh"
echo "✅ 설치 완료 ($MODE): $DEST"

# 의존성 점검 — 둘 중 하나만 있어도 사용 가능하므로 경고만 표시
echo
echo "의존성 점검:"
for bin in codex agy python3; do
  if command -v "$bin" >/dev/null; then echo "  ✅ $bin"; else echo "  ⚠️  $bin 없음"; fi
done
if command -v timeout >/dev/null || command -v gtimeout >/dev/null; then
  echo "  ✅ timeout"
else
  echo "  ⚠️  timeout 없음 (macOS: brew install coreutils)"
fi
echo
echo "Claude Code 를 재시작하면 스킬이 인식됩니다. 예: \"codex한테 이 함수 리뷰 받아봐\""
