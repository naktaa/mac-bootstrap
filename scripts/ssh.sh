#!/bin/zsh

configure_github_ssh() {
  local ssh_dir="$HOME/.ssh" key="$HOME/.ssh/id_ed25519"
  local downloaded_key="$HOME/Downloads/id_ed25519" config="$HOME/.ssh/config"
  local marker_begin='# >>> mac-bootstrap GitHub SSH >>>'
  local marker_end='# <<< mac-bootstrap GitHub SSH <<<'
  local effective_config

  section "GitHub SSH (macOS Agent / Keychain)"

  if [ ! -e "$key" ] && [ ! -L "$key" ] && [ ! -f "$downloaded_key" ]; then
    log_skip "개인키가 없습니다. ~/Downloads/id_ed25519를 다운로드한 뒤 다시 실행하세요."
    return 0
  fi

  if [ "$DRY_RUN" -eq 1 ]; then
    log_change "기존 개인키를 보존하고, 없으면 ~/Downloads/id_ed25519를 복사합니다."
    log_change "~/.ssh 700, 개인키 600 및 GitHub SSH 설정을 적용합니다."
    log_change "ssh-add --apple-use-keychain으로 macOS Agent에 등록합니다."
    return 0
  fi

  if ! /bin/mkdir -p "$ssh_dir" || ! /bin/chmod 700 "$ssh_dir"; then
    log_warn "~/.ssh 디렉터리 또는 권한 설정 실패. 나머지 작업을 계속합니다."
    return 0
  fi

  if [ -e "$key" ] || [ -L "$key" ]; then
    log_skip "기존 ~/.ssh/id_ed25519를 보존합니다."
  else
    if ! (umask 077; /bin/cp -n "$downloaded_key" "$key"); then
      log_warn "SSH 개인키 복사 실패. 나머지 작업을 계속합니다."
      return 0
    fi
    log_change "다운로드한 SSH 개인키를 ~/.ssh/id_ed25519에 복사했습니다."
  fi

  if [ ! -f "$key" ] || ! /bin/chmod 600 "$key"; then
    log_warn "SSH 개인키 파일 또는 권한을 확인하세요: $key"
    return 0
  fi

  if /usr/bin/grep -Fqx "$marker_begin" "$config" 2>/dev/null; then
    if /usr/bin/grep -Fqx "$marker_end" "$config"; then
      log_skip "GitHub SSH 관리 블록: 이미 존재"
    else
      log_warn "~/.ssh/config의 GitHub SSH 관리 블록이 불완전합니다. 직접 확인하세요."
    fi
  elif /usr/bin/grep -Fqx "$marker_end" "$config" 2>/dev/null; then
    log_warn "~/.ssh/config의 GitHub SSH 관리 블록이 불완전합니다. 직접 확인하세요."
  else
    # OrbStack Include와 기존 설정 순서를 보존하고, Host *로 범위를 복원한다.
    if (umask 077; cat >> "$config" <<EOF

$marker_begin
Host github.com
    HostName github.com
    User git
    AddKeysToAgent yes
    UseKeychain yes
    IdentityFile ~/.ssh/id_ed25519
Host *
$marker_end
EOF
    ); then
      log_change "~/.ssh/config에 GitHub SSH 설정을 추가했습니다."
    else
      log_warn "GitHub SSH 설정 저장 실패. 나머지 작업을 계속합니다."
    fi
  fi

  # 먼저 선언된 사용자 설정이 우선하므로 충돌은 덮어쓰지 않고 안내한다.
  if effective_config="$(/usr/bin/ssh -G github.com 2>/dev/null)"; then
    if ! printf '%s\n' "$effective_config" | /usr/bin/grep -Eq '^addkeystoagent (yes|true)$'; then
      log_warn "기존 SSH 설정이 GitHub의 AddKeysToAgent 설정보다 우선합니다. ~/.ssh/config를 확인하세요."
    fi
  else
    log_warn "SSH 설정 검증 실패. ~/.ssh/config를 확인하세요."
  fi

  if /usr/bin/ssh-add --apple-use-keychain "$key"; then
    log_ok "GitHub 개인키를 macOS SSH Agent / Keychain에 등록했습니다."
  else
    log_warn "SSH Agent 등록 실패. macOS Terminal에서 /usr/bin/ssh-add --apple-use-keychain ~/.ssh/id_ed25519를 다시 실행하세요."
  fi
  return 0
}
