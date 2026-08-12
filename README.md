# mac-bootstrap

코디세이 교육장의 공용 iMac에서 반복해서 초기화되는 개인 설정을
`./setup.sh` 한 번으로 복원하기 위한 macOS bootstrap 저장소다.

## 최초 실행

강의장 Mac의 Terminal에서 실행한다.

```bash
git clone https://github.com/naktaa/mac-bootstrap.git
cd mac-bootstrap
chmod +x setup.sh
./setup.sh --dry-run
./setup.sh
```

- `--dry-run`: 실제로 변경하지 않고 현재 상태와 변경 예정 항목만 출력
- 옵션 없는 실행: 설정을 실제 적용
- 두 번째 실행부터는 이미 원하는 상태인 항목을 `[SKIP]` 처리

한 항목이 실패해도 나머지 설정은 계속 진행하며 마지막에 결과를
요약한다. 키 반복이나 단축키가 즉시 반영되지 않으면 한 번 로그아웃한 뒤
다시 로그인한다.

## 자동화 항목

| 구분 | 설정 내용 |
|---|---|
| 마우스 | 자연스러운 스크롤을 꺼서 Windows 방식의 휠 방향 사용 |
| 키보드 | 빠른 키 반복과 짧은 반복 시작 지연 |
| 입력 소스 | 기본 영문과 두벌식 한글 입력 활성화 |
| 한/영 전환 | 이전 입력 소스 선택을 `Control-Space`로 설정 |
| Spotlight | `Command-Space`, `Option-Command-Space` 단축키 해제 |
| zsh | history, prompt와 자주 사용하는 alias 적용 |
| Vim | 줄 번호, 4칸 Tab·들여쓰기, 상태 줄, cindent, syntax 적용 |
| Git | global 이름, 이메일, 기본 branch 적용 |

SSH, VS Code, Docker, Homebrew, 응용프로그램 설치는 자동화하지 않는다.

## Git 이름과 이메일 설정 위치

공개되어도 괜찮다면 `config.sh`에서 다음 두 줄을 본인 값으로 바꾸는 것이
가장 간단하다.

```zsh
GIT_USER_NAME="본인 이름"
GIT_USER_EMAIL="본인 이메일"
GIT_DEFAULT_BRANCH="main"
```

예:

```zsh
GIT_USER_NAME="Naktaa"
GIT_USER_EMAIL="example@gmail.com"
GIT_DEFAULT_BRANCH="main"
```

setup은 현재 global 값과 비교하고 다를 때만 다음과 같은 설정을 적용한다.

```bash
git config --global user.name "Naktaa"
git config --global user.email "example@gmail.com"
git config --global init.defaultBranch main
```

이름과 이메일을 저장소에 올리고 싶지 않다면 다음 방식도 사용할 수 있다.

```bash
cp config.local.sh.example config.local.sh
```

그다음 `config.local.sh`에서 값을 수정한다. 이 파일은 `.gitignore`에
포함되어 Git에 올라가지 않으며 `config.sh`보다 나중에 적용된다.

## zsh alias 수정 위치

저장소에서 관리하는 alias는 `dotfiles/zshrc.managed`에 있다. 현재 다음
alias가 포함되어 있다.

```zsh
alias gs="git status"
alias gl="git log --oneline --graph --decorate --all"
alias ll="ls -al"
alias c='clear'
alias py='python3 main.py'
```

alias를 추가하거나 변경하려면 `dotfiles/zshrc.managed`를 수정하고 저장소에
commit한다. 다음 Mac에서 `./setup.sh`를 실행하면 수정된 파일이
`~/.config/mac-bootstrap/zshrc`에 복사된다.

기존 `~/.zshrc`는 덮어쓰지 않는다. 다음 연결 블록만 한 번 추가한다.

```zsh
# >>> mac-bootstrap >>>
[ -f "$HOME/.config/mac-bootstrap/zshrc" ] && source "$HOME/.config/mac-bootstrap/zshrc"
# <<< mac-bootstrap <<<
```

setup 실행 직후 현재 Terminal에도 바로 반영하려면 다음을 실행한다.

```bash
source ~/.zshrc
```

## Vim 설정 수정 위치

Vim 설정은 `dotfiles/vimrc.managed`에 있다. 요청한 설정은 다음과 같이
포함되어 있다.

```vim
set nu
set ts=4
set sw=4
set ls=2
set cindent
syntax on
```

각 설정의 의미는 다음과 같다.

- `set nu`: 줄 번호 표시
- `set ts=4`: Tab 문자를 화면에서 4칸으로 표시
- `set sw=4`: 자동 들여쓰기 폭을 4칸으로 설정
- `set ls=2`: 창이 하나뿐이어도 상태 줄을 항상 표시
- `set cindent`: C 계열 문법 기준 자동 들여쓰기
- `syntax on`: 파일 형식에 따른 문법 강조

setup은 파일을 `~/.config/mac-bootstrap/vimrc`에 복사하고 기존 `~/.vimrc`에
관리 파일을 불러오는 블록만 추가한다. 기존 Vim 설정은 보존되며 변경
전 `~/.vimrc`도 백업한다.

Vim 설정을 추가하려면 `dotfiles/vimrc.managed`를 수정한 후 setup을 다시
실행하면 된다. 다음에 Vim을 열 때부터 새 설정이 적용된다.

## 주요 설정값

일반 설정은 `config.sh`에서 수정한다.

```zsh
NATURAL_SCROLLING=false
KEY_REPEAT=2
INITIAL_KEY_REPEAT=15

ENSURE_KOREAN_INPUT=true
CONFIGURE_CONTROL_SPACE=true
DISABLE_SPOTLIGHT_SHORTCUTS=true

MANAGE_ZSH=true
MANAGE_VIM=true
```

`KEY_REPEAT`와 `INITIAL_KEY_REPEAT`는 숫자가 작을수록 빠르다. `2`와 `15`는
macOS 설정 UI의 빠른 반복과 짧은 지연에 가까운 값이다.

## 한글 입력과 단축키 처리 방식

두벌식 입력은 macOS Text Input Source API를 이용한다. 내부 plist의 입력
소스 배열을 직접 덮어쓰지 않는다. 기본 영문과 두벌식이 이미 활성화되어
있으면 다시 추가하지 않는다.

시스템 단축키는 기존 dictionary를 유지하면서 다음 항목만 변경한다.

- symbolic hotkey ID `60`: `Control-Space` 입력 소스 전환
- symbolic hotkey ID `64`: Spotlight 검색 비활성화
- symbolic hotkey ID `65`: Spotlight 분류의 Finder 검색 단축키 비활성화

구조가 예상과 다르거나 MDM 정책으로 변경이 차단되면 해당 단계만 경고를
출력하고 다음 단계로 넘어간다. 이 경우 다음 경로에서 직접 변경한다.

```text
시스템 설정 > 키보드 > 텍스트 입력 > 편집
시스템 설정 > 키보드 > 키보드 단축키 > 입력 소스
시스템 설정 > 키보드 > 키보드 단축키 > Spotlight
```

## 백업

실제 변경이 필요한 경우에만 다음 위치에 백업한다.

```text
~/.mac-bootstrap-backups/YYYYMMDD-HHMMSS-PID/
```

다음 파일이 상황에 따라 생성된다.

- `input-sources.plist`
- `symbolic-hotkeys.plist`
- `zshrc.before-bootstrap`
- `vimrc.before-bootstrap`

## 출력 메시지

- `[CHANGE]`: 실제 변경 또는 dry-run의 변경 예정 항목
- `[SKIP]`: 이미 원하는 상태이거나 config에서 비활성화한 항목
- `[OK]`: 검사 또는 적용 후 확인 완료
- `[WARN]`: 수동 확인이 필요하지만 나머지 setup은 계속 진행
- `[ERROR]`: 작업 실패; 나머지는 계속하지만 최종 종료 코드는 `1`

## 참고 문서

- [Apple: Korean Input Method User Guide](https://support.apple.com/guide/korean-input-method/welcome/mac)
- [Apple: macOS 키보드 단축키 비활성화](https://support.apple.com/guide/mac-help/keyboard-shortcuts-mchlp2262/mac)
- [Apple Developer: TISEnableInputSource 사용 예](https://developer.apple.com/library/archive/qa/qa1810/_index.html)
