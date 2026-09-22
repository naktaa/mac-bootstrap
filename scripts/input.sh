#!/bin/zsh

CAPS_LOCK_HELPER="$SCRIPT_DIR/scripts/helpers/caps-lock-fn.js"
HOTKEY_HELPER="$SCRIPT_DIR/scripts/helpers/symbolic-hotkeys.js"
HOTKEYS_BACKED_UP=0

# USB HID usage 값. imac-setup과 같은 Caps Lock -> fn(지구본) 매핑이다.
CAPS_LOCK_HID_USAGE=30064771129
FN_HID_USAGE=1095216660483

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

list_keyboards() {
  /usr/sbin/ioreg -r -c IOHIDInterface -l -w 0 2>/dev/null | /usr/bin/awk '
    /^\+-o/               { flush(); vendor=""; product=""; country=""; keyboard=0 }
    /"VendorID" =/        { vendor = $NF }
    /"ProductID" =/       { product = $NF }
    /"CountryCode" =/     { country = $NF }
    /"PrimaryUsage" = 6$/ { keyboard = 1 }
    /"DeviceUsagePage"=1,"DeviceUsage"=6[},]/ { keyboard = 1 }
    END { flush() }
    function flush() {
      if (keyboard && vendor != "" && product != "") {
        print vendor "-" product "-" (country == "" ? 0 : country)
      }
    }
  ' | /usr/bin/sort -u
}

caps_lock_mapping_is_saved() {
  keyboard_id="$1"
  mapping_key="com.apple.keyboard.modifiermapping.$keyboard_id"
  mapping_state="$(/usr/bin/defaults -currentHost read -g "$mapping_key" 2>/dev/null)" || return 1
  printf '%s\n' "$mapping_state" | /usr/bin/grep -Fq \
    "HIDKeyboardModifierMappingSrc = $CAPS_LOCK_HID_USAGE;" || return 1
  printf '%s\n' "$mapping_state" | /usr/bin/grep -Fq \
    "HIDKeyboardModifierMappingDst = $FN_HID_USAGE;"
}

configure_caps_lock_input_switch() {
  if ! is_true "$CONFIGURE_CAPS_LOCK_INPUT_SWITCH"; then
    log_skip "Caps Lock 입력 소스 전환: config에서 비활성화"
    return 0
  fi

  keyboards="$(list_keyboards)"
  if [ -z "$keyboards" ]; then
    keyboards="1452-591-0"
    log_warn "연결된 키보드를 찾지 못해 Apple Magic Keyboard 기본 식별자를 사용합니다."
  fi

  fn_usage_ok=0
  if default_read com.apple.HIToolbox AppleFnUsageType && [ "$DEFAULT_VALUE" = "1" ]; then
    fn_usage_ok=1
  fi

  mappings_ok=1
  for keyboard_id in $keyboards; do
    caps_lock_mapping_is_saved "$keyboard_id" || mappings_ok=0
  done

  if [ "$fn_usage_ok" -eq 1 ] && [ "$mappings_ok" -eq 1 ]; then
    log_skip "Caps Lock 입력 소스 전환: 이미 설정됨"
    return 0
  fi

  log_change "Caps Lock을 fn(지구본)으로 바꾸고 입력 소스 전환에 사용합니다."
  SYSTEM_SETTINGS_CHANGED=1
  if [ "$DRY_RUN" -eq 1 ]; then
    return 0
  fi

  if [ "$fn_usage_ok" -ne 1 ]; then
    backup_defaults_domain com.apple.HIToolbox hitoolbox-before-caps-lock.plist || return 0
    if ! /usr/bin/defaults write com.apple.HIToolbox AppleFnUsageType -int 1; then
      log_error "fn 키 동작을 입력 소스 변경으로 설정하지 못했습니다."
      return 1
    fi
  fi

  if [ "$mappings_ok" -ne 1 ]; then
    backup_current_host_defaults_domain NSGlobalDomain current-host-global-preferences.plist || return 0
    mapping_pair="<dict><key>HIDKeyboardModifierMappingSrc</key><integer>$CAPS_LOCK_HID_USAGE</integer><key>HIDKeyboardModifierMappingDst</key><integer>$FN_HID_USAGE</integer></dict>"
    for keyboard_id in $keyboards; do
      mapping_key="com.apple.keyboard.modifiermapping.$keyboard_id"
      if ! /usr/bin/defaults -currentHost write -g "$mapping_key" -array "$mapping_pair"; then
        log_error "Caps Lock 매핑을 저장하지 못했습니다: $keyboard_id"
        return 1
      fi
    done
  fi

  applied_count="$(/usr/bin/osascript -l JavaScript "$CAPS_LOCK_HELPER" \
    "$CAPS_LOCK_HID_USAGE" "$FN_HID_USAGE" 2>/dev/null)"
  apply_status=$?
  if [ "$apply_status" -ne 0 ] || [ "${applied_count:-0}" -le 0 ] 2>/dev/null; then
    log_warn "Caps Lock 매핑을 즉시 적용하지 못했습니다. 로그아웃 후 다시 로그인하면 적용됩니다."
  else
    log_ok "연결된 키보드 ${applied_count}개 서비스에 Caps Lock 매핑 즉시 적용"
  fi

  verified=1
  if ! default_read com.apple.HIToolbox AppleFnUsageType || [ "$DEFAULT_VALUE" != "1" ]; then
    verified=0
  fi
  for keyboard_id in $keyboards; do
    caps_lock_mapping_is_saved "$keyboard_id" || verified=0
  done

  if [ "$verified" -eq 1 ]; then
    log_ok "Caps Lock -> fn -> 입력 소스 변경 설정 저장 확인"
  else
    log_warn "Caps Lock 입력 소스 전환 설정을 저장한 뒤 다시 확인하지 못했습니다."
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

  configure_caps_lock_input_switch

  hotkey_state="$(inspect_hotkeys)"
  hotkey_status=$?
  if [ "$hotkey_status" -ne 0 ]; then
    log_warn "macOS symbolic hotkey 구조를 읽지 못했습니다: $hotkey_state"
    log_warn "Spotlight 단축키는 시스템 설정에서 직접 변경하세요."
    return 0
  fi

  configure_spotlight_shortcuts "$hotkey_state"
}
