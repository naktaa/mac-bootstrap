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

func findSource() -> TISInputSource? {
    let filter = [kTISPropertyInputSourceID as String: inputSourceID] as CFDictionary
    guard let sources = TISCreateInputSourceList(filter, true)?.takeRetainedValue() as? [TISInputSource] else {
        return nil
    }
    return sources.first
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

var source = findSource()
if source == nil, command == "enable", let location = installedBundle {
    let result = TISRegisterInputSource(location as CFURL)
    guard result == noErr else { fail("구름 입력기 등록 실패 (OSStatus \(result)).") }
    source = findSource()
}

guard let source else {
    print(installedBundle == nil ? "missing" : "unregistered")
    exit(command == "enable" ? 1 : 0)
}

if command == "enable" && !isEnabled(source) {
    let result = TISEnableInputSource(source)
    guard result == noErr else { fail("구름 두벌식 활성화 실패 (OSStatus \(result)).") }
    for _ in 0..<10 {
        if let refreshed = findSource(), isEnabled(refreshed) { break }
        Thread.sleep(forTimeInterval: 0.2)
    }
}

// plist에 항목만 존재하는 경우를 활성화 성공으로 오인하지 않는다.
let enabled = findSource().map(isEnabled) ?? false
print(enabled ? "enabled" : "disabled")
if command == "enable" && !enabled {
    fail("macOS 입력 서비스에서 활성화를 확인하지 못했습니다. 로그아웃 후 다시 실행하세요.")
}
