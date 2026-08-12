#!/bin/zsh

print_environment() {
  product_version="$(/usr/bin/sw_vers -productVersion 2>/dev/null || printf '알 수 없음')"
  build_version="$(/usr/bin/sw_vers -buildVersion 2>/dev/null || printf '알 수 없음')"
  architecture="$(/usr/bin/uname -m)"
  current_user="$(/usr/bin/id -un)"
  host_name="$(/usr/sbin/scutil --get ComputerName 2>/dev/null || /bin/hostname)"

  printf '=== macOS Bootstrap ===\n\n'
  printf 'User         : %s\n' "$current_user"
  printf 'macOS        : %s (%s)\n' "$product_version" "$build_version"
  printf 'Architecture : %s\n' "$architecture"
  printf 'Host         : %s\n' "$host_name"
}

configure_core_macos() {
  section "마우스와 키보드"

  # 자연스러운 스크롤은 전역 설정이므로 연결된 마우스와 트랙패드에
  # 같은 방향으로 적용된다. false면 Windows와 같은 휠 방향이다.
  apply_default_bool NSGlobalDomain com.apple.swipescrolldirection \
    "$NATURAL_SCROLLING" "자연스러운 스크롤"

  # KeyRepeat와 InitialKeyRepeat는 숫자가 작을수록 빠르다.
  # 설정 후 새로 실행하는 앱부터 반영되며 로그아웃 후에는 전체에 반영된다.
  apply_default_number NSGlobalDomain KeyRepeat "$KEY_REPEAT" -int \
    "키 반복 속도"
  apply_default_number NSGlobalDomain InitialKeyRepeat "$INITIAL_KEY_REPEAT" -int \
    "반복 입력 시작 지연"
}

apply_shortcut_changes() {
  section "설정 반영"

  if [ "$SHORTCUTS_CHANGED" -eq 0 ]; then
    log_skip "즉시 반영할 단축키 변경 없음"
    return 0
  fi

  if [ "$DRY_RUN" -eq 1 ]; then
    log_change "실제 실행에서는 변경한 키보드 단축키의 즉시 반영을 시도합니다."
    return 0
  fi

  activation_tool="/System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings"
  if [ -x "$activation_tool" ] && "$activation_tool" -u >/dev/null 2>&1; then
    log_ok "키보드 단축키 설정 활성화 완료"
  else
    log_warn "단축키 즉시 활성화 도구를 사용할 수 없습니다. 로그아웃 후 확실히 반영됩니다."
  fi
}
