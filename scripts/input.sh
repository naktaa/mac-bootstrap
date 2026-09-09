#!/bin/zsh

INPUT_HELPER="$SCRIPT_DIR/scripts/helpers/input-source.js"
HOTKEY_HELPER="$SCRIPT_DIR/scripts/helpers/symbolic-hotkeys.js"
HOTKEYS_BACKED_UP=0

inspect_korean_input() {
  /usr/bin/osascript -l JavaScript "$INPUT_HELPER" inspect 2>&1
}

inspect_hotkeys() {
  /usr/bin/osascript -l JavaScript "$HOTKEY_HELPER" inspect 2>&1
}

ensure_hotkey_backup() {
  if [ "$HOTKEYS_BACKED_UP" -eq 1 ]; then
    return 0
  fi
  backup_defaults_domain com.apple.symbolichotkeys symbolic-hotkeys.plist || return 1
  HOTKEYS_BACKED_UP=1
}

configure_korean_input() {
  if ! is_true "$ENSURE_KOREAN_INPUT"; then
    log_skip "두벌식 한글 입력: config에서 비활성화"
    return 0
  fi

  korean_state="$(inspect_korean_input)"
  korean_status=$?
  if [ "$korean_status" -ne 0 ]; then
    log_warn "한글 입력 소스 API를 호출하지 못했습니다: $korean_state"
    log_warn "시스템 설정 > 키보드 > 텍스트 입력 > 편집에서 '두벌식'을 추가하세요."
    return 0
  fi

  if printf '%s\n' "$korean_state" | /usr/bin/grep -q '^KOREAN_ENABLED=true$' && \
     printf '%s\n' "$korean_state" | /usr/bin/grep -q '^LATIN_ENABLED=true$'; then
    log_skip "기본 영문과 두벌식 한글 입력: 이미 활성화됨"
    return 0
  fi

  if ! printf '%s\n' "$korean_state" | /usr/bin/grep -q '^KOREAN_AVAILABLE=true$'; then
    log_warn "macOS 기본 두벌식 입력 소스를 찾지 못했습니다."
    log_warn "시스템 설정 > 키보드 > 텍스트 입력 > 편집에서 직접 추가하세요."
    return 0
  fi

  log_change "기본 영문과 두벌식 한글 입력 소스를 활성화합니다."
  if [ "$DRY_RUN" -eq 1 ]; then
    return 0
  fi

  backup_defaults_domain com.apple.HIToolbox input-sources.plist
  enable_result="$(/usr/bin/osascript -l JavaScript "$INPUT_HELPER" enable 2>&1)"
  enable_status=$?
  if [ "$enable_status" -ne 0 ]; then
    log_warn "두벌식 입력 소스 활성화에 실패했습니다: $enable_result"
    log_warn "시스템 설정 > 키보드 > 텍스트 입력 > 편집에서 직접 추가하세요."
    return 0
  fi

  verified_state="$(inspect_korean_input)"
  if printf '%s\n' "$verified_state" | /usr/bin/grep -q '^KOREAN_ENABLED=true$' && \
     printf '%s\n' "$verified_state" | /usr/bin/grep -q '^LATIN_ENABLED=true$'; then
    log_ok "기본 영문과 두벌식 한글 입력 활성화 확인"
  else
    log_warn "API 호출 후 두벌식 활성 상태를 확인하지 못했습니다. 로그아웃 후 확인하세요."
  fi
}

configure_control_space() {
  if ! is_true "$CONFIGURE_CONTROL_SPACE"; then
    log_skip "Control-Space 입력 전환: config에서 비활성화"
    return 0
  fi

  hotkey_state="$1"
  if printf '%s\n' "$hotkey_state" | /usr/bin/grep -q '^INPUT_SWITCH_ENABLED=true$' && \
     printf '%s\n' "$hotkey_state" | /usr/bin/grep -q '^INPUT_SWITCH_PARAMETERS=32,49,262144$'; then
    log_skip "입력 소스 전환: 이미 Control-Space"
    return 0
  fi

  log_change "입력 소스 전환 단축키를 Control-Space로 설정합니다."
  SHORTCUTS_CHANGED=1
  if [ "$DRY_RUN" -eq 1 ]; then
    return 0
  fi

  ensure_hotkey_backup || return 0
  result="$(/usr/bin/osascript -l JavaScript "$HOTKEY_HELPER" configure-control-space 2>&1)"
  hotkey_apply_status=$?
  if [ "$hotkey_apply_status" -ne 0 ]; then
    log_warn "Control-Space 자동 설정에 실패했습니다: $result"
    log_warn "시스템 설정 > 키보드 > 키보드 단축키 > 입력 소스에서 직접 설정하세요."
    return 0
  fi

  if printf '%s\n' "$result" | /usr/bin/grep -q '^INPUT_SWITCH_ENABLED=true$' && \
     printf '%s\n' "$result" | /usr/bin/grep -q '^INPUT_SWITCH_PARAMETERS=32,49,262144$'; then
    log_ok "Control-Space 입력 전환 설정 확인"
  else
    log_warn "Control-Space 값을 저장했지만 즉시 확인하지 못했습니다."
  fi
}

configure_spotlight_shortcuts() {
  if ! is_true "$DISABLE_SPOTLIGHT_SHORTCUTS"; then
    log_skip "Spotlight 단축키: config에서 유지"
    return 0
  fi

  hotkey_state="$1"
  spotlight64_ok=0
  spotlight65_ok=0
  printf '%s\n' "$hotkey_state" | /usr/bin/grep -Eq '^SPOTLIGHT_64_ENABLED=(false|missing)$' && spotlight64_ok=1
  printf '%s\n' "$hotkey_state" | /usr/bin/grep -Eq '^SPOTLIGHT_65_ENABLED=(false|missing)$' && spotlight65_ok=1

  if [ "$spotlight64_ok" -eq 1 ] && [ "$spotlight65_ok" -eq 1 ]; then
    log_skip "Spotlight 단축키: 이미 모두 비활성화됨"
    return 0
  fi

  log_change "Spotlight의 Command-Space와 Option-Command-Space를 비활성화합니다."
  SHORTCUTS_CHANGED=1
  if [ "$DRY_RUN" -eq 1 ]; then
    return 0
  fi

  ensure_hotkey_backup || return 0
  result="$(/usr/bin/osascript -l JavaScript "$HOTKEY_HELPER" disable-spotlight 2>&1)"
  hotkey_apply_status=$?
  if [ "$hotkey_apply_status" -ne 0 ]; then
    log_warn "Spotlight 단축키 자동 설정에 실패했습니다: $result"
    log_warn "시스템 설정 > 키보드 > 키보드 단축키 > Spotlight에서 직접 해제하세요."
    return 0
  fi

  if printf '%s\n' "$result" | /usr/bin/grep -Eq '^SPOTLIGHT_64_ENABLED=(false|missing)$' && \
     printf '%s\n' "$result" | /usr/bin/grep -Eq '^SPOTLIGHT_65_ENABLED=(false|missing)$'; then
    log_ok "Spotlight 단축키 비활성화 확인"
  else
    log_warn "Spotlight 값을 저장했지만 즉시 확인하지 못했습니다."
  fi
}

configure_input_environment() {
  section "한글 입력과 단축키"

  if [ ! -x /usr/bin/osascript ]; then
    log_warn "osascript를 사용할 수 없어 입력 환경 자동화를 건너뜁니다."
    return 0
  fi

  configure_korean_input

  hotkey_state="$(inspect_hotkeys)"
  hotkey_status=$?
  if [ "$hotkey_status" -ne 0 ]; then
    log_warn "macOS symbolic hotkey 구조를 읽지 못했습니다: $hotkey_state"
    log_warn "입력 소스와 Spotlight 단축키는 시스템 설정에서 직접 변경하세요."
    return 0
  fi

  configure_control_space "$hotkey_state"

  # 앞 단계에서 실제 변경했다면 최신 상태를 다시 읽어 Spotlight를 처리한다.
  if [ "$DRY_RUN" -eq 0 ] && [ "$SHORTCUTS_CHANGED" -eq 1 ]; then
    hotkey_state="$(inspect_hotkeys)"
  fi
  configure_spotlight_shortcuts "$hotkey_state"
}
