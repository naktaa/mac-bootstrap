#!/bin/zsh

# mac-bootstrap의 단일 진입점이다.
# 기능별 스크립트를 불러오고, 한 항목이 실패해도 다음 항목을 계속 실행한다.

SCRIPT_DIR="$(CDPATH= cd -- "$(/usr/bin/dirname -- "$0")" && /bin/pwd -P)"
DRY_RUN=0

usage() {
  cat <<'EOF'
사용법: ./setup.sh [--dry-run] [--help]

  --dry-run  실제 파일과 시스템 설정을 변경하지 않고 예정 작업만 출력
  --help     도움말 출력
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --dry-run) DRY_RUN=1 ;;
    --help|-h) usage; exit 0 ;;
    *) printf '[ERROR] 알 수 없는 옵션: %s\n' "$1" >&2; usage; exit 2 ;;
  esac
  shift
done

# zsh에서 미일치 glob이 오류가 되지 않도록 한다.
if [ -n "${ZSH_VERSION:-}" ]; then
  setopt NULL_GLOB
  setopt PIPE_FAIL
fi

. "$SCRIPT_DIR/lib/common.sh"
. "$SCRIPT_DIR/config.sh"
if [ -f "$SCRIPT_DIR/config.local.sh" ]; then
  . "$SCRIPT_DIR/config.local.sh"
fi

. "$SCRIPT_DIR/scripts/macos.sh"
. "$SCRIPT_DIR/scripts/input.sh"
. "$SCRIPT_DIR/scripts/shell-git.sh"

validate_config() {
  validation_failed=0

  for entry in \
    "NATURAL_SCROLLING:$NATURAL_SCROLLING" \
    "ENSURE_KOREAN_INPUT:$ENSURE_KOREAN_INPUT" \
    "CONFIGURE_CONTROL_SPACE:$CONFIGURE_CONTROL_SPACE" \
    "DISABLE_SPOTLIGHT_SHORTCUTS:$DISABLE_SPOTLIGHT_SHORTCUTS" \
    "MANAGE_ZSH:$MANAGE_ZSH" \
    "MANAGE_VIM:$MANAGE_VIM"
  do
    name="${entry%%:*}"
    value="${entry#*:}"
    validate_boolean "$name" "$value" || validation_failed=1
  done

  validate_integer "KEY_REPEAT" "$KEY_REPEAT" || validation_failed=1
  validate_integer "INITIAL_KEY_REPEAT" "$INITIAL_KEY_REPEAT" || validation_failed=1

  [ "$validation_failed" -eq 0 ]
}

if [ "$(/usr/bin/uname -s)" != "Darwin" ]; then
  log_error "이 스크립트는 macOS에서만 실행할 수 있습니다."
  print_summary
  exit 1
fi

if ! validate_config; then
  printf '\n설정값 오류를 수정한 뒤 다시 실행하세요.\n' >&2
  print_summary
  exit 2
fi

print_environment
if [ "$DRY_RUN" -eq 1 ]; then
  printf '\n[DRY RUN] 실제 시스템과 사용자 파일을 변경하지 않습니다.\n'
fi

configure_core_macos
configure_input_environment
configure_shell
configure_vim
configure_git
apply_shortcut_changes

print_summary

if [ "$ERROR_COUNT" -gt 0 ]; then
  exit 1
fi
exit 0
