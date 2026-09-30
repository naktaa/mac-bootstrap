#!/usr/bin/swift

import Carbon
import Foundation

let inputSourceID = "org.youknowone.inputmethod.Gureum.han2"
let command = CommandLine.arguments.dropFirst().first ?? "status"

guard command == "status" || command == "enable" else {
    fputs("usage: gureum-input-source.swift [status|enable]\n", stderr)
    exit(2)
}

guard let sources = TISCreateInputSourceList(nil, true)?.takeRetainedValue() as? [TISInputSource] else {
    fputs("입력 소스 목록을 읽지 못했습니다.\n", stderr)
    exit(1)
}

let source = sources.first { candidate in
    guard let property = TISGetInputSourceProperty(candidate, kTISPropertyInputSourceID) else {
        return false
    }
    let identifier = Unmanaged<CFString>.fromOpaque(property).takeUnretainedValue() as String
    return identifier == inputSourceID
}

guard let source else {
    print("missing")
    exit(0)
}

func isAdded() -> Bool {
    let preferences = UserDefaults(suiteName: "com.apple.HIToolbox")
    let entries = preferences?.array(forKey: "AppleEnabledInputSources") as? [[String: Any]] ?? []
    return entries.contains { entry in
        entry["Bundle ID"] as? String == "org.youknowone.inputmethod.Gureum" &&
        entry["Input Mode"] as? String == inputSourceID
    }
}

if command == "enable" && !isAdded() {
    let result = TISEnableInputSource(source)
    guard result == noErr else {
        fputs("구름 두벌식 활성화 실패 (OSStatus \(result)).\n", stderr)
        exit(1)
    }
    // 입력 소스 설정은 text input service가 비동기로 갱신할 수 있다.
    for _ in 0..<5 where !isAdded() {
        Thread.sleep(forTimeInterval: 0.2)
    }

    // 일부 macOS 버전은 성공을 반환해도 사용자 입력 소스 목록을 갱신하지 않는다.
    // 그때만 기존 목록에 이 입력 모드를 추가한다.
    if !isAdded() {
        guard let preferences = UserDefaults(suiteName: "com.apple.HIToolbox") else {
            fputs("입력 소스 설정을 열지 못했습니다.\n", stderr)
            exit(1)
        }
        guard var entries = preferences.array(forKey: "AppleEnabledInputSources") as? [[String: Any]] else {
            fputs("기존 입력 소스 목록을 읽지 못했습니다.\n", stderr)
            exit(1)
        }
        entries.append([
            "Bundle ID": "org.youknowone.inputmethod.Gureum",
            "Input Mode": inputSourceID,
            "InputSourceKind": "Input Mode"
        ])
        preferences.set(entries, forKey: "AppleEnabledInputSources")
        guard preferences.synchronize() else {
            fputs("입력 소스 설정을 저장하지 못했습니다.\n", stderr)
            exit(1)
        }
    }
}

let added = isAdded()
print(added ? "enabled" : "disabled")
if command == "enable" && !added {
    exit(1)
}
