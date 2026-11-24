#!/bin/zsh

# 모든 스크립트가 공유하는 출력, 비교, dry-run, 백업 함수다.

CHANGE_COUNT=0
DONE_COUNT=0
SKIP_COUNT=0
OK_COUNT=0
WARN_COUNT=0
ERROR_COUNT=0
SHORTCUTS_CHANGED=0
SYSTEM_SETTINGS_CHANGED=0
BACKUP_DIR=""

# 섹션별 결과를 모아 실행 요약에 표시한다.
SECTION_NAMES=()
SECTION_RESULTS=()
CURRENT_SECTION=""
SEC_CHANGE=0
SEC_DONE=0
SEC_SKIP=0
SEC_WARN=0
SEC_ERROR=0

if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  COLOR_GREEN='\033[32m'
  COLOR_YELLOW='\033[33m'
  COLOR_RED='\033[31m'
  COLOR_CYAN='\033[36m'
  COLOR_DIM='\033[2m'
  COLOR_BOLD='\033[1m'
  COLOR_RESET='\033[0m'
else
  COLOR_GREEN=''
  COLOR_YELLOW=''
  COLOR_RED=''
  COLOR_CYAN=''
  COLOR_DIM=''
  COLOR_BOLD=''
  COLOR_RESET=''
fi

# 라벨은 터미널 표시 폭 6칸으로 맞춘다(한글 1자 = 2칸).
# 상태 열 폭: 들여쓰기 2 + 기호 1 + 공백 1 + 라벨 6 + 공백 2 = 12
DETAIL_INDENT='            '
DIVIDER='────────────────────────────────────────────────'

print_status_line() {
  # $1=색 $2=기호 $3=라벨(6칸) $4=메시지
  printf '  %b%s %s%b  %s\n' "$1" "$2" "$3" "$COLOR_RESET" "$4"
}

# 이미 원하는 상태인 항목
log_done() {
  DONE_COUNT=$((DONE_COUNT + 1))
  SEC_DONE=$((SEC_DONE + 1))
  print_status_line "$COLOR_GREEN" '✔' '설정됨' "$*"
}

# 변경 예정(dry-run) 또는 변경하는 항목. 결과는 log_ok/log_warn/log_error로 이어진다.
log_change() {
  CHANGE_COUNT=$((CHANGE_COUNT + 1))
  SEC_CHANGE=$((SEC_CHANGE + 1))
  if [ "${DRY_RUN:-0}" -eq 1 ]; then
    print_status_line "$COLOR_CYAN" '➜' '예정  ' "$*"
  else
    print_status_line "$COLOR_CYAN" '➜' '변경  ' "$*"
  fi
}

# config에서 끄거나 조건이 맞지 않아 실행하지 않은 항목
log_skip() {
  SKIP_COUNT=$((SKIP_COUNT + 1))
  SEC_SKIP=$((SEC_SKIP + 1))
  print_status_line "$COLOR_DIM" '–' '제외  ' "$*"
}

log_warn() {
  WARN_COUNT=$((WARN_COUNT + 1))
  SEC_WARN=$((SEC_WARN + 1))
  print_status_line "$COLOR_YELLOW" '!' '경고  ' "$*"
}

log_error() {
  ERROR_COUNT=$((ERROR_COUNT + 1))
  SEC_ERROR=$((SEC_ERROR + 1))
  print_status_line "$COLOR_RED" '✖' '실패  ' "$*" >&2
}

# 직전 항목에 딸린 적용·검증 성공 결과
log_ok() {
  OK_COUNT=$((OK_COUNT + 1))
  printf '%s%b└ ✔ %s%b\n' "$DETAIL_INDENT" "$COLOR_GREEN" "$*" "$COLOR_RESET"
}

# 직전 항목에 딸린 참고 정보(백업 위치 등)
log_detail() {
  printf '%s%b└ %s%b\n' "$DETAIL_INDENT" "$COLOR_DIM" "$*" "$COLOR_RESET"
}

print_header() {
  printf '\n%b▶ %s%b\n' "$COLOR_BOLD" "$1" "$COLOR_RESET"
  printf '%b%s%b\n' "$COLOR_DIM" "$DIVIDER" "$COLOR_RESET"
}

close_section() {
  [ -n "$CURRENT_SECTION" ] || return 0
  local result
  if [ "$SEC_ERROR" -gt 0 ]; then
    result="error:$SEC_ERROR"
  elif [ "$SEC_WARN" -gt 0 ]; then
    result="warn:$SEC_WARN"
  elif [ "$SEC_CHANGE" -gt 0 ]; then
    result="change:$SEC_CHANGE"
  elif [ "$SEC_DONE" -gt 0 ]; then
    result="done:$SEC_DONE"
  else
    result="skip:$SEC_SKIP"
  fi
  SECTION_NAMES+=("$CURRENT_SECTION")
  SECTION_RESULTS+=("$result")
  CURRENT_SECTION=""
  SEC_CHANGE=0
  SEC_DONE=0
  SEC_SKIP=0
  SEC_WARN=0
  SEC_ERROR=0
}

section() {
  close_section
  CURRENT_SECTION="$1"
  print_header "$1"
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
    log_done "$label: $desired"
    return 0
  fi

  log_change "$label: $current -> $desired"
  SYSTEM_SETTINGS_CHANGED=1
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
    log_done "$label: $desired"
    return 0
  fi

  log_change "$label: $current -> $desired"
  SYSTEM_SETTINGS_CHANGED=1
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
  log_detail "백업 생성: $BACKUP_DIR/$backup_name"
}

backup_defaults_domain() {
  domain="$1"
  backup_name="$2"
  [ "$DRY_RUN" -eq 0 ] || return 0
  ensure_backup_dir || return 1
  if /usr/bin/defaults export "$domain" "$BACKUP_DIR/$backup_name" >/dev/null 2>&1; then
    log_detail "설정 백업 생성: $BACKUP_DIR/$backup_name"
    return 0
  fi
  log_warn "$domain 설정이 아직 없어 백업을 만들지 못했습니다."
  return 0
}

backup_current_host_defaults_domain() {
  domain="$1"
  backup_name="$2"
  [ "$DRY_RUN" -eq 0 ] || return 0
  ensure_backup_dir || return 1
  if /usr/bin/defaults -currentHost export "$domain" "$BACKUP_DIR/$backup_name" >/dev/null 2>&1; then
    log_detail "현재 호스트 설정 백업 생성: $BACKUP_DIR/$backup_name"
    return 0
  fi
  log_warn "$domain 현재 호스트 설정이 아직 없어 백업을 만들지 못했습니다."
  return 0
}

print_summary() {
  close_section
  print_header "실행 요약"

  local i name result kind count pad
  for (( i = 1; i <= ${#SECTION_NAMES}; i++ )); do
    name="${SECTION_NAMES[i]}"
    result="${SECTION_RESULTS[i]}"
    kind="${result%%:*}"
    count="${result#*:}"
    # 한글 폭을 고려해 섹션 이름을 24칸으로 맞춘다.
    pad=$(( 24 - ${(m)#name} ))
    [ "$pad" -ge 1 ] || pad=1
    printf '  %s%*s' "$name" "$pad" ''
    case "$kind" in
      error)  printf '%b✖ 실패 (%s건)%b\n' "$COLOR_RED" "$count" "$COLOR_RESET" ;;
      warn)   printf '%b! 경고 (%s건)%b\n' "$COLOR_YELLOW" "$count" "$COLOR_RESET" ;;
      change)
        if [ "${DRY_RUN:-0}" -eq 1 ]; then
          printf '%b➜ 변경 예정 (%s건)%b\n' "$COLOR_CYAN" "$count" "$COLOR_RESET"
        else
          printf '%b✔ 성공 (변경 %s건)%b\n' "$COLOR_GREEN" "$count" "$COLOR_RESET"
        fi
        ;;
      done)   printf '%b✔ 성공%b\n' "$COLOR_GREEN" "$COLOR_RESET" ;;
      *)      printf '%b– 제외%b\n' "$COLOR_DIM" "$COLOR_RESET" ;;
    esac
  done

  local change_label='변경'
  [ "${DRY_RUN:-0}" -eq 0 ] || change_label='변경 예정'
  printf '\n  %s %s · 설정됨 %s · 제외 %s · 경고 %s · 실패 %s\n' \
    "$change_label" "$CHANGE_COUNT" "$DONE_COUNT" "$SKIP_COUNT" "$WARN_COUNT" "$ERROR_COUNT"
  if [ -n "$BACKUP_DIR" ]; then
    printf '  백업 위치: %s\n' "$BACKUP_DIR"
  fi

  printf '\n'
  if [ "$ERROR_COUNT" -gt 0 ]; then
    printf '  %b%b✖ 실패 %s건이 있습니다. 위의 ✖ 항목을 확인하세요.%b\n' \
      "$COLOR_BOLD" "$COLOR_RED" "$ERROR_COUNT" "$COLOR_RESET"
  elif [ "$WARN_COUNT" -gt 0 ]; then
    printf '  %b%b! 경고 %s건과 함께 완료했습니다. 위의 ! 항목을 확인하세요.%b\n' \
      "$COLOR_BOLD" "$COLOR_YELLOW" "$WARN_COUNT" "$COLOR_RESET"
  elif [ "${DRY_RUN:-0}" -eq 1 ]; then
    printf '  %b%b➜ DRY RUN 완료: 변경 예정 %s건 (실제로 바꾼 것은 없습니다)%b\n' \
      "$COLOR_BOLD" "$COLOR_CYAN" "$CHANGE_COUNT" "$COLOR_RESET"
  else
    printf '  %b%b✔ 모든 설정이 완료되었습니다.%b\n' \
      "$COLOR_BOLD" "$COLOR_GREEN" "$COLOR_RESET"
  fi
}
