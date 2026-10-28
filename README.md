# mac-bootstrap

코디세이 교육장의 공용 iMac에서 반복해서 초기화되는 개인 설정을
`./setup.sh` 한 번으로 복원하기 위한 macOS bootstrap 저장소다.

## 최초 실행

강의장 Mac의 Terminal에서 실행한다.

```bash
git clone https://github.com/naktaa/mac-bootstrap.git
cd mac-bootstrap
./setup.sh --dry-run
./setup.sh
```

- `--dry-run`: 실제로 변경하지 않고 현재 상태와 변경 예정 항목만 출력
- 옵션 없는 실행: 설정을 실제 적용하고, Terminal에서 성공하면 새 로그인 zsh로 진입
- `--no-reload-shell`: 설정 적용만 하고 새 셸은 실행하지 않음
- 두 번째 실행부터는 이미 원하는 상태인 항목을 `[SKIP]` 처리

한 항목이 실패해도 나머지 설정은 계속 진행하며 마지막에 결과를
요약한다. 키보드·마우스·단축키를 변경하면 macOS 설정 활성화 도구로
즉시 반영을 시도하며, 활성화 도구를 사용할 수 없다는 경고가 나오면 한 번
로그아웃한 뒤 다시 로그인한다.

## 자동화 항목

| 구분 | 설정 내용 |
|---|---|
| 마우스 | 자연스러운 스크롤을 꺼서 Windows 방식의 휠 방향 사용 |
| 키보드 | 빠른 키 반복, 짧은 반복 시작 지연, 자동으로 대문자 시작 끄기 |
| 화면 | 내장 디스플레이 밝기를 60%로 설정 |
| 입력 소스 | 구름 입력기가 설치돼 있으면 두벌식 입력 소스를 추가하고 기존 입력 소스는 유지 |
| 한/영 전환 | Caps Lock을 `fn/지구본`으로 바꿔 입력 소스 전환 |
| 받아쓰기 | 단축키와 fn 연타 활성화 안내 해제, 해제 저장 실패 시 드문 조합으로 변경 |
| Spotlight | `Command-Space`, `Option-Command-Space` 단축키 해제 |
| 스크린샷 | `Control-Shift-S`로 선택 영역을 캡처해 클립보드에 복사 |
| zsh | history, prompt와 자주 사용하는 alias 적용 |
| Vim | 줄 번호, 4칸 Tab·들여쓰기, 상태 줄, cindent, syntax 적용 |
| Git | global 이름, 이메일, 기본 branch 적용 |
| GitHub SSH | 다운로드한 개인키 설치, 권한 설정, macOS Agent·Keychain 등록 |

VS Code, Docker, Homebrew, 응용프로그램 설치는 자동화하지 않는다.

## 매주 초기화 후 GitHub SSH 사용

1. GitHub 계정에 공개키가 이미 등록된 개인키를 `~/Downloads/id_ed25519`로 다운로드한다.
2. macOS에서 `./setup.sh`를 실행한다.
3. OrbStack을 실행하고 Linux Machine을 수동으로 생성한다.
4. Linux Machine에서 Linux-bootstrap의 `./install.sh`를 실행한다.
5. GitHub clone/push를 사용한다. Linux에서는 `https://github.com/` 주소도 SSH로 변환된다.

macOS setup은 `~/.ssh/id_ed25519`가 없을 때만 다운로드한 키를 복사한다.
기존 키는 덮어쓰지 않으며, `~/.ssh`는 700, 개인키는 600으로 설정한다.
`~/.ssh/config`의 기존 내용과 OrbStack Include를 보존하고 GitHub 전용
`AddKeysToAgent yes`, `UseKeychain yes`, `IdentityFile ~/.ssh/id_ed25519` 블록을
한 번만 추가한다. 기존 설정이 `AddKeysToAgent`보다 우선하면 경고한다.
Apple 기본 `/usr/bin/ssh-add --apple-use-keychain`으로 Agent에 등록하며,
암호화된 키는 최초 등록 시 암호 입력이 필요할 수 있다.
키가 없으면 안내만 출력하고, SSH 설정이나 Agent 등록이 실패해도 나머지 작업은 계속한다.
`--dry-run`에서는 키 복사·설정 변경·Agent 등록을 실행하지 않는다.

[OrbStack은 macOS SSH Agent를 Linux Machine에 자동 전달한다](https://docs.orbstack.dev/machines/ssh#agent-forwarding).
별도의 `ForwardAgent` 설정이나 Linux 개인키 복사·생성은 필요 없다.
macOS SSH 설정과 Linux Git URL 변환은 각 부트스트랩이 독립적으로 처리한다.

필요할 때 macOS와 Linux에서 다음 명령으로 확인한다.

```bash
ssh-add -l
ssh -T git@github.com
```

첫 GitHub 접속에서는 호스트 키 확인이 나올 수 있다.
`Hi ...! You've successfully authenticated`가 나오면 인증 성공이다
(GitHub는 셸을 제공하지 않아 이 경우에도 종료 코드 1을 반환한다).
Linux의 `ssh-add -l`에 키가 없으면 macOS에서 Agent 등록 결과를 먼저 확인한다.

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

setup이 성공하면 대화형 Terminal에서 자동으로 `exec /bin/zsh -l`을 실행해
새 셸에 변경된 alias와 설정을 반영한다. setup 프로세스가 새 셸로 교체되므로
새 셸에서 `exit`하면 기존 부모 셸로 돌아간다. 부모 셸까지 교체하려면 기존처럼
`./setup.sh --no-reload-shell && exec /bin/zsh -l`을 사용한다.
`--dry-run`, 오류 발생, 비대화형 실행에서는 새 셸을 열지 않는다.
`RELOAD_ZSH_AFTER_SETUP=false`로 자동 진입을 끌 수 있다.

```bash
./setup.sh
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
AUTOMATIC_CAPITALIZATION=false
DISPLAY_BRIGHTNESS_PERCENT=60

CONFIGURE_GUREUM_HAN2=true
CONFIGURE_CAPS_LOCK_INPUT_SWITCH=true
DISABLE_DICTATION_SHORTCUT=true
DISABLE_SPOTLIGHT_SHORTCUTS=true
CONFIGURE_SCREENSHOT_CLIPBOARD_SHORTCUT=true

MANAGE_ZSH=true
RELOAD_ZSH_AFTER_SETUP=true
MANAGE_VIM=true
```

`KEY_REPEAT`와 `INITIAL_KEY_REPEAT`는 숫자가 작을수록 빠르다. `2`와 `15`는
macOS 설정 UI의 빠른 반복과 짧은 지연에 가까운 값이다.
`AUTOMATIC_CAPITALIZATION=false`는 시스템 설정의
`키보드 > 텍스트 입력 > 편집 > 자동으로 대문자 시작` 체크를 해제한다.

## 화면 밝기

`DISPLAY_BRIGHTNESS_PERCENT=60`은 내장 화면 밝기를 약 60%로 설정한다.
0~100의 정수를 사용하며, 빈 문자열(`""`)이면 현재 밝기를 유지한다.
Swift와 macOS의 비공개 DisplayServices API를 사용하며 별도 앱은 설치하지 않는다.
내장 화면이 없거나 API를 지원하지 않으면 경고 후 다음 설정을 진행한다.
외장 모니터는 제어하지 않는다. 자동 밝기는 변경하지 않으므로 주변 조명에 따라
실행 이후 밝기가 다시 달라질 수 있다.

## 한글 입력과 단축키 처리 방식

구름 입력기 앱이 이미 설치돼 있으면 macOS 입력 소스 API로 구름 두벌식
(`org.youknowone.inputmethod.Gureum.han2`)을 추가한다. 기존 입력 소스는
유지하며, 상위 구름 입력기와 두벌식 모드가 모두 활성화돼 있으면 건너뛴다.
`CONFIGURE_GUREUM_HAN2=false`로
이 단계를 끌 수 있다. 구름이 설치돼 있지 않거나 macOS가 입력기를 인식하지
못하면 경고를 출력하고 나머지 설정을 계속한다. 이 단계에는 Xcode Command
Line Tools의 Swift가 필요하다. 구름 설치 자체는 자동화하지 않는다. macOS가
아직 설치된 앱을 등록하지 않았다면 `TISRegisterInputSource`로 등록을 시도한다.
`TISEnableInputSource`로 상위 구름 입력기를 먼저 활성화한 뒤 두벌식 모드를
활성화한다. 상위 입력 소스는 앱의 Bundle ID와 입력기 타입으로 찾는다.
두 호출의 반환 코드로 오류를 처리하며, 활성화 후 반복 조회는 하지 않는다.
plist 목록에 항목만 있다고 성공으로 처리하거나 plist를 직접 추가하지 않는다.
메뉴에서 바로 보이지 않으면 로그아웃한 뒤 다시 로그인한다.

한/영 전환은 `imac-setup`과 같은 방식으로 구성한다.

1. `AppleFnUsageType=1`로 설정해 `fn/지구본` 키의 동작을 입력 소스 변경으로 지정한다.
2. 연결된 키보드의 Vendor ID, Product ID, Country Code를 찾는다.
3. 해당 키보드의 ByHost modifier 설정에 `Caps Lock → fn/지구본` 매핑을 저장한다.
4. IOKit HID 이벤트 시스템에도 같은 매핑을 넣어 즉시 적용한다.

따라서 Caps Lock을 누르면 현재 활성화된 입력 소스가 전환된다. 활성 입력 소스가
`ABC`와 구름 두벌식뿐이면 두 입력기 사이를 전환한다. 실제 `fn/지구본` 키도
입력 소스 변경으로 동작한다. Caps Lock 본래의 대문자 잠금 기능은 사용할 수 없다.

받아쓰기 단축키(symbolic hotkey ID `164`)는 비활성화하고,
`AppleDictationAutoEnable=0`으로 fn 연타 시 활성화 안내도 억제한다.
단축키 해제 값을 저장한 뒤 확인하지 못하면 `Control-Option-Shift-Command-F12`로
변경을 시도한다. 현재 Caps Lock 한/영 전환은 유지한다.
`DISABLE_DICTATION_SHORTCUT=false`로 이 단계를 끌 수 있다.
검증은 설정 저장값을 확인하며, 즉시 반영되지 않으면 로그아웃 후 다시 로그인한다.

키보드별 modifier 배열은 Caps Lock에서 fn으로 가는 단일 매핑으로 저장한다.
같은 키보드에 별도의 사용자 지정 modifier 매핑이 있다면 교체된다.

시스템 단축키는 기존 dictionary를 유지하면서 다음 항목만 변경한다.

- symbolic hotkey ID `64`: Spotlight 검색 비활성화
- symbolic hotkey ID `65`: Spotlight 분류의 Finder 검색 단축키 비활성화
- symbolic hotkey ID `31`: 선택 영역을 클립보드에 복사하는 단축키를 `Control-Shift-S`로 설정

구조가 예상과 다르거나 MDM 정책으로 변경이 차단되면 해당 단계만 경고를
출력하고 다음 단계로 넘어간다. 이 경우 다음 경로에서 직접 변경한다.

```text
시스템 설정 > 키보드 > fn 키를 눌러 > 입력 소스 변경
시스템 설정 > 키보드 > 키보드 단축키 > 보조 키
시스템 설정 > 키보드 > 키보드 단축키 > Spotlight
시스템 설정 > 키보드 > 키보드 단축키 > 스크린샷
```

## 백업

실제 변경이 필요한 경우에만 다음 위치에 백업한다.

```text
~/.mac-bootstrap-backups/YYYYMMDD-HHMMSS-PID/
```

다음 파일이 상황에 따라 생성된다.

- `hitoolbox-before-caps-lock.plist`
- `hitoolbox-before-gureum.plist`
- `hitoolbox-before-dictation.plist`
- `current-host-global-preferences.plist`
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
- [Apple: Third-Party Input Method Management Changes](https://developer.apple.com/library/archive/qa/qa1810/_index.html)
- [brightness: DisplayServices 밝기 API 구현 참고](https://github.com/nriley/brightness/blob/master/brightness.c)
- [Gureum: 설치와 입력 소스 추가](https://github.com/gureum/gureum#설치)
- [Apple: macOS 키보드 단축키 비활성화](https://support.apple.com/guide/mac-help/keyboard-shortcuts-mchlp2262/mac)
