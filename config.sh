#!/bin/zsh

# ==========================================================
# mac-bootstrap 개인 설정
#
# 이 파일에는 저장소에 공개해도 되는 기본값만 둔다.
# 이름·이메일처럼 개인별로 바꾸고 싶은 값은
# config.local.sh.example을 config.local.sh로 복사해 설정한다.
# ==========================================================

# Windows와 같은 휠 방향을 사용하기 위해 자연스러운 스크롤을 끈다.
NATURAL_SCROLLING=false

# 키를 누르고 있을 때 반복되는 속도다. 숫자가 작을수록 빠르다.
# 2는 macOS 설정 UI의 가장 빠른 단계에 가까운 값이다.
KEY_REPEAT=2

# 키를 누른 뒤 반복 입력이 시작될 때까지의 지연이다.
# 숫자가 작을수록 반복이 빨리 시작되며, 15는 UI의 짧은 지연에 가깝다.
INITIAL_KEY_REPEAT=15

# macOS 기본 두벌식 한글 입력 소스를 활성화한다.
ENSURE_KOREAN_INPUT=true

# 이전 입력 소스 선택 단축키를 Control-Space로 지정한다.
# 영문과 두벌식만 사용할 때 사실상 한/영 전환으로 동작한다.
CONFIGURE_CONTROL_SPACE=true

# Spotlight 검색(Command-Space)과 Finder 검색 창
# (Option-Command-Space) 단축키를 비활성화한다.
DISABLE_SPOTLIGHT_SHORTCUTS=true

# 관리되는 zsh 설정을 ~/.zshrc에서 불러오도록 구성한다.
MANAGE_ZSH=true

# 관리되는 Vim 설정을 ~/.vimrc에서 불러오도록 구성한다.
MANAGE_VIM=true

# 아래 두 값을 본인 이름과 이메일로 바꾸면 setup이 Git global 설정에 적용한다.
# 빈 문자열이면 기존 Git 설정을 유지한다.
GIT_USER_NAME="nakta-cody"
GIT_USER_EMAIL="moneydon77@naver.com"
GIT_DEFAULT_BRANCH="main"
