#!/bin/zsh

# 모든 스크립트가 공유하는 출력, 비교, dry-run, 백업 함수다.

CHANGE_COUNT=0
SKIP_COUNT=0
OK_COUNT=0
WARN_COUNT=0
ERROR_COUNT=0
SHORTCUTS_CHANGED=0
BACKUP_DIR=""

if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  COLOR_GREEN='\033[32m'
  COLOR_YELLOW='\033[33m'
  COLOR_RED='\033[31m'
  COLOR_CYAN='\033[36m'
  COLOR_RESET='\033[0m'
else
  COLOR_GREEN=''
  COLOR_YELLOW=''
  COLOR_RED=''
  COLOR_CYAN=''
  COLOR_RESET=''
fi

log_ok() {
  OK_COUNT=$((OK_COUNT + 1))
  printf '%b[OK]%b %s\n' "$COLOR_GREEN" "$COLOR_RESET" "$*"
}

log_change() {
  CHANGE_COUNT=$((CHANGE_COUNT + 1))
  printf '%b[CHANGE]%b %s\n' "$COLOR_CYAN" "$COLOR_RESET" "$*"
}

log_skip() {
  SKIP_COUNT=$((SKIP_COUNT + 1))
  printf '[SKIP] %s\n' "$*"
}

log_warn() {
  WARN_COUNT=$((WARN_COUNT + 1))
  printf '%b[WARN]%b %s\n' "$COLOR_YELLOW" "$COLOR_RESET" "$*"
}

log_error() {
  ERROR_COUNT=$((ERROR_COUNT + 1))
  printf '%b[ERROR]%b %s\n' "$COLOR_RED" "$COLOR_RESET" "$*" >&2
}

section() {
  printf '\n=== %s ===\n' "$1"
}

is_true() {
  case "${1:-}" in
    true|TRUE|1|yes|YES|on|ON) return 0 ;;
    *) return 1 ;;
  esac
}

is_boolean() {
  case "${1:-}" in
    true|TRUE|false|FALSE|1|0|yes|YES|no|NO|on|ON|off|OFF) return 0 ;;
    *) return 1 ;;
  esac
}

boolean_word() {
  if is_true "$1"; then
    printf 'true'
  else
    printf 'false'
  fi
}

validate_integer() {
  case "$2" in
    ''|*[!0-9]*) log_error "$1은(는) 0 이상의 정수여야 합니다: $2"; return 1 ;;
    *) return 0 ;;
  esac
}

validate_boolean() {
  if ! is_boolean "$2"; then
    log_error "$1은(는) true 또는 false여야 합니다: $2"
    return 1
  fi
}

default_read() {
  DEFAULT_VALUE="$(/usr/bin/defaults read "$1" "$2" 2>/dev/null)"
  DEFAULT_STATUS=$?
  [ "$DEFAULT_STATUS" -eq 0 ]
}

normalize_boolean() {
  case "${1:-}" in
    1|true|TRUE|yes|YES) printf 'true' ;;
    0|false|FALSE|no|NO) printf 'false' ;;
    *) printf '%s' "$1" ;;
  esac
}

numeric_equal() {
  /usr/bin/awk -v left="$1" -v right="$2" 'BEGIN { exit !((left + 0) == (right + 0)) }'
}

apply_default_bool() {
  domain="$1"
  key="$2"
  desired="$(boolean_word "$3")"
  label="$4"

  if default_read "$domain" "$key"; then
    current="$(normalize_boolean "$DEFAULT_VALUE")"
  else
    current="미설정(시스템 기본값)"
  fi

  if [ "$current" = "$desired" ]; then
    log_skip "$label: 이미 $desired"
    return 0
  fi

  log_change "$label: $current -> $desired"
  if [ "$DRY_RUN" -eq 1 ]; then
    return 0
  fi

  if ! /usr/bin/defaults write "$domain" "$key" -bool "$desired"; then
    log_error "$label 변경 명령이 실패했습니다."
    return 1
  fi

  if default_read "$domain" "$key" && [ "$(normalize_boolean "$DEFAULT_VALUE")" = "$desired" ]; then
    return 0
  fi

  log_warn "$label 값을 다시 읽었지만 원하는 값이 아닙니다. MDM 정책을 확인하세요."
  return 1
}

apply_default_number() {
  domain="$1"
  key="$2"
  desired="$3"
  value_type="$4"
  label="$5"

  if default_read "$domain" "$key"; then
    current="$DEFAULT_VALUE"
  else
    current="미설정(시스템 기본값)"
  fi

  if [ "$current" != "미설정(시스템 기본값)" ] && numeric_equal "$current" "$desired"; then
    log_skip "$label: 이미 $desired"
    return 0
  fi

  log_change "$label: $current -> $desired"
  if [ "$DRY_RUN" -eq 1 ]; then
    return 0
  fi

  if ! /usr/bin/defaults write "$domain" "$key" "$value_type" "$desired"; then
    log_error "$label 변경 명령이 실패했습니다."
    return 1
  fi

  if default_read "$domain" "$key" && numeric_equal "$DEFAULT_VALUE" "$desired"; then
    return 0
  fi

  log_warn "$label 값을 다시 읽었지만 원하는 값이 아닙니다. MDM 정책을 확인하세요."
  return 1
}

ensure_backup_dir() {
  if [ -n "$BACKUP_DIR" ]; then
    return 0
  fi

  timestamp="$(/bin/date '+%Y%m%d-%H%M%S')"
  BACKUP_DIR="$HOME/.mac-bootstrap-backups/$timestamp-$$"
  /bin/mkdir -p "$BACKUP_DIR" || {
    log_error "백업 디렉터리를 만들 수 없습니다: $BACKUP_DIR"
    BACKUP_DIR=""
    return 1
  }
}

backup_file() {
  source_file="$1"
  backup_name="$2"
  [ -e "$source_file" ] || return 0
  [ "$DRY_RUN" -eq 0 ] || return 0
  ensure_backup_dir || return 1
  /bin/cp -p "$source_file" "$BACKUP_DIR/$backup_name" || {
    log_error "파일 백업에 실패했습니다: $source_file"
    return 1
  }
  log_ok "백업 생성: $BACKUP_DIR/$backup_name"
}

backup_defaults_domain() {
  domain="$1"
  backup_name="$2"
  [ "$DRY_RUN" -eq 0 ] || return 0
  ensure_backup_dir || return 1
  if /usr/bin/defaults export "$domain" "$BACKUP_DIR/$backup_name" >/dev/null 2>&1; then
    log_ok "설정 백업 생성: $BACKUP_DIR/$backup_name"
    return 0
  fi
  log_warn "$domain 설정이 아직 없어 백업을 만들지 못했습니다."
  return 0
}

print_summary() {
  section "실행 요약"
  printf '변경 예정/적용 : %s\n' "$CHANGE_COUNT"
  printf '이미 설정됨     : %s\n' "$SKIP_COUNT"
  printf '확인 완료       : %s\n' "$OK_COUNT"
  printf '경고            : %s\n' "$WARN_COUNT"
  printf '오류            : %s\n' "$ERROR_COUNT"
  if [ -n "$BACKUP_DIR" ]; then
    printf '백업 위치       : %s\n' "$BACKUP_DIR"
  fi
}
