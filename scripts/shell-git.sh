#!/bin/zsh

configure_shell() {
  section "zsh"

  if ! is_true "$MANAGE_ZSH"; then
    log_skip "zsh 설정: config에서 비활성화"
    return 0
  fi

  source_file="$SCRIPT_DIR/dotfiles/zshrc.managed"
  managed_dir="$HOME/.config/mac-bootstrap"
  managed_file="$managed_dir/zshrc"
  user_zshrc="$HOME/.zshrc"
  marker_begin="# >>> mac-bootstrap >>>"
  marker_end="# <<< mac-bootstrap <<<"
  source_line='[ -f "$HOME/.config/mac-bootstrap/zshrc" ] && source "$HOME/.config/mac-bootstrap/zshrc"'

  if [ -f "$managed_file" ] && /usr/bin/cmp -s "$source_file" "$managed_file"; then
    log_skip "관리 zsh 설정 파일: 이미 최신"
  else
    log_change "관리 zsh 설정을 $managed_file에 설치합니다."
    if [ "$DRY_RUN" -eq 0 ]; then
      /bin/mkdir -p "$managed_dir" || {
        log_error "zsh 설정 디렉터리를 만들 수 없습니다: $managed_dir"
        return 0
      }
      if ! /bin/cp "$source_file" "$managed_file"; then
        log_error "관리 zsh 설정 복사에 실패했습니다."
        return 0
      fi
    fi
  fi

  if [ -f "$user_zshrc" ] && /usr/bin/grep -Fq "$marker_begin" "$user_zshrc"; then
    if /usr/bin/grep -Fq "$source_line" "$user_zshrc" && \
       /usr/bin/grep -Fq "$marker_end" "$user_zshrc"; then
      log_skip "~/.zshrc 연결 블록: 이미 존재"
    else
      log_warn "~/.zshrc의 mac-bootstrap marker 블록이 불완전합니다. 직접 확인하세요."
    fi
    return 0
  fi

  log_change "기존 ~/.zshrc를 보존하고 mac-bootstrap 연결 블록을 추가합니다."
  if [ "$DRY_RUN" -eq 1 ]; then
    return 0
  fi

  backup_file "$user_zshrc" zshrc.before-bootstrap || return 0
  {
    [ ! -s "$user_zshrc" ] || printf '\n'
    printf '%s\n' "$marker_begin"
    printf '%s\n' "$source_line"
    printf '%s\n' "$marker_end"
  } >> "$user_zshrc" || log_error "~/.zshrc 연결 블록을 추가하지 못했습니다."
}

configure_vim() {
  section "Vim"

  if ! is_true "$MANAGE_VIM"; then
    log_skip "Vim 설정: config에서 비활성화"
    return 0
  fi

  source_file="$SCRIPT_DIR/dotfiles/vimrc.managed"
  managed_dir="$HOME/.config/mac-bootstrap"
  managed_file="$managed_dir/vimrc"
  user_vimrc="$HOME/.vimrc"
  marker_begin='" >>> mac-bootstrap >>>'
  marker_end='" <<< mac-bootstrap <<<'
  source_line='execute "source " . fnameescape(expand("$HOME/.config/mac-bootstrap/vimrc"))'

  if [ -f "$managed_file" ] && /usr/bin/cmp -s "$source_file" "$managed_file"; then
    log_skip "관리 Vim 설정 파일: 이미 최신"
  else
    log_change "관리 Vim 설정을 $managed_file에 설치합니다."
    if [ "$DRY_RUN" -eq 0 ]; then
      /bin/mkdir -p "$managed_dir" || {
        log_error "Vim 설정 디렉터리를 만들 수 없습니다: $managed_dir"
        return 0
      }
      if ! /bin/cp "$source_file" "$managed_file"; then
        log_error "관리 Vim 설정 복사에 실패했습니다."
        return 0
      fi
    fi
  fi

  if [ -f "$user_vimrc" ] && /usr/bin/grep -Fq "$marker_begin" "$user_vimrc"; then
    if /usr/bin/grep -Fq "$source_line" "$user_vimrc" && \
       /usr/bin/grep -Fq "$marker_end" "$user_vimrc"; then
      log_skip "~/.vimrc 연결 블록: 이미 존재"
    else
      log_warn "~/.vimrc의 mac-bootstrap marker 블록이 불완전합니다. 직접 확인하세요."
    fi
    return 0
  fi

  log_change "기존 ~/.vimrc를 보존하고 mac-bootstrap 연결 블록을 추가합니다."
  if [ "$DRY_RUN" -eq 1 ]; then
    return 0
  fi

  backup_file "$user_vimrc" vimrc.before-bootstrap || return 0
  {
    [ ! -s "$user_vimrc" ] || printf '\n'
    printf '%s\n' "$marker_begin"
    printf '%s\n' "$source_line"
    printf '%s\n' "$marker_end"
  } >> "$user_vimrc" || log_error "~/.vimrc 연결 블록을 추가하지 못했습니다."
}

apply_git_config() {
  key="$1"
  desired="$2"
  label="$3"

  current="$(/usr/bin/git config --global --get "$key" 2>/dev/null)"
  if [ "$current" = "$desired" ]; then
    log_skip "$label: 이미 $desired"
    return 0
  fi

  if [ -n "$current" ]; then
    display_current="$current"
  else
    display_current="미설정"
  fi
  log_change "$label: $display_current -> $desired"
  if [ "$DRY_RUN" -eq 0 ] && ! /usr/bin/git config --global "$key" "$desired"; then
    log_error "$label 설정에 실패했습니다."
  fi
}

configure_git() {
  section "Git global 설정"

  if ! command -v git >/dev/null 2>&1; then
    log_warn "Git이 없어 global 설정을 건너뜁니다."
    return 0
  fi

  if [ -n "$GIT_USER_NAME" ]; then
    apply_git_config user.name "$GIT_USER_NAME" "Git user.name"
  else
    log_warn "GIT_USER_NAME이 비어 있어 기존 값을 유지합니다. config.sh 또는 config.local.sh에서 설정하세요."
  fi

  if [ -n "$GIT_USER_EMAIL" ]; then
    apply_git_config user.email "$GIT_USER_EMAIL" "Git user.email"
  else
    log_warn "GIT_USER_EMAIL이 비어 있어 기존 값을 유지합니다. config.sh 또는 config.local.sh에서 설정하세요."
  fi

  if [ -n "$GIT_DEFAULT_BRANCH" ]; then
    apply_git_config init.defaultBranch "$GIT_DEFAULT_BRANCH" "Git 기본 branch"
  fi
}
