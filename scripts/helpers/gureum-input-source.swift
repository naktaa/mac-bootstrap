#!/usr/bin/swift

import Carbon
import Foundation

let bundleID = "org.youknowone.inputmethod.Gureum"
let inputSourceID = "\(bundleID).han2"
let command = CommandLine.arguments.dropFirst().first ?? "status"

func fail(_ message: String) -> Never {
    fputs("\(message)\n", stderr)
    exit(1)
}

guard command == "status" || command == "enable" else {
    fail("usage: gureum-input-source.swift [status|enable]")
}

func findSource(matching properties: [String: String]) -> TISInputSource? {
    let filter = properties as CFDictionary
    guard let sources = TISCreateInputSourceList(filter, true)?.takeRetainedValue() as? [TISInputSource] else {
        return nil
    }
    return sources.first
}

func findMode() -> TISInputSource? {
    findSource(matching: [kTISPropertyInputSourceID as String: inputSourceID])
}

func findInputMethod() -> TISInputSource? {
    // 상위 입력 소스 ID는 앱의 Bundle ID와 다를 수 있으므로 타입으로 찾는다.
    findSource(matching: [
        kTISPropertyBundleID as String: bundleID,
        kTISPropertyInputSourceType as String: kTISTypeKeyboardInputMethodModeEnabled as String
    ])
}

func isEnabled(_ source: TISInputSource) -> Bool {
    guard let property = TISGetInputSourceProperty(source, kTISPropertyInputSourceIsEnabled) else {
        return false
    }
    return CFBooleanGetValue(Unmanaged<CFBoolean>.fromOpaque(property).takeUnretainedValue())
}

// 설치 직후 아직 등록되지 않은 앱도 찾는다. status에서는 등록하지 않는다.
let directories = [
    FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Input Methods"),
    URL(fileURLWithPath: "/Library/Input Methods")
]
let installedBundle = directories.lazy.flatMap { directory in
    (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
}.first { Bundle(url: $0)?.bundleIdentifier == bundleID }

var source = findMode()
var inputMethod = findInputMethod()
if source == nil || inputMethod == nil, command == "enable", let location = installedBundle {
    let result = TISRegisterInputSource(location as CFURL)
    guard result == noErr else { fail("구름 입력기 등록 실패 (OSStatus \(result)).") }
    source = findMode()
    inputMethod = findInputMethod()
}

guard let source, let inputMethod else {
    print(installedBundle == nil ? "missing" : "unregistered")
    exit(command == "enable" ? 1 : 0)
}

if command == "enable" {
    // 두벌식 모드만 enabled여도 상위 입력기가 꺼져 있으면 선택할 수 없다.
    // 이미 활성화된 경우에도 안전하게 두 단계 모두 활성화를 요청한다.
    let methodResult = TISEnableInputSource(inputMethod)
    guard methodResult == noErr else {
        fail("구름 입력기 활성화 실패 (OSStatus \(methodResult)).")
    }
    guard let refreshedMode = findMode() else {
        fail("구름 입력기 활성화 후 두벌식 입력 소스를 찾지 못했습니다.")
    }
    let modeResult = TISEnableInputSource(refreshedMode)
    guard modeResult == noErr else {
        fail("구름 두벌식 활성화 실패 (OSStatus \(modeResult)).")
    }
    print("enabled")
    exit(0)
}

// 이미 설정됐는지 확인할 때는 상위 입력기와 모드가 모두 활성화돼야 한다.
let enabled = isEnabled(inputMethod) && isEnabled(source)
print(enabled ? "enabled" : "disabled")
