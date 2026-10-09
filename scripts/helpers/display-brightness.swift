#!/usr/bin/swift

import CoreGraphics
import Darwin
import Foundation

func fail(_ message: String) -> Never {
    fputs("\(message)\n", stderr)
    exit(1)
}

let arguments = Array(CommandLine.arguments.dropFirst())
guard arguments == ["status"] ||
    (arguments.count == 2 && arguments[0] == "set" &&
     Int(arguments[1]).map({ (0...100).contains($0) }) == true) else {
    fail("usage: display-brightness.swift status | set <0-100>")
}

var displays = [CGDirectDisplayID](repeating: 0, count: 16)
var count: UInt32 = 0
guard CGGetOnlineDisplayList(UInt32(displays.count), &displays, &count) == .success else {
    fail("디스플레이 목록을 읽지 못했습니다.")
}
guard let display = displays.prefix(Int(count)).first(where: { CGDisplayIsBuiltin($0) != 0 }) else {
    fail("내장 디스플레이가 없어 밝기 설정을 건너뜁니다.")
}

// DisplayServices는 비공개 API이므로 심볼이 없는 macOS에서는 안전하게 실패한다.
guard let library = dlopen("/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices", RTLD_LAZY) else {
    fail("DisplayServices를 사용할 수 없습니다.")
}
defer { dlclose(library) }
typealias GetBrightness = @convention(c) (UInt32, UnsafeMutablePointer<Float>) -> Int32
typealias SetBrightness = @convention(c) (UInt32, Float) -> Int32
guard let getSymbol = dlsym(library, "DisplayServicesGetBrightness"),
      let setSymbol = dlsym(library, "DisplayServicesSetBrightness") else {
    fail("이 macOS에서는 밝기 API를 사용할 수 없습니다.")
}
let getBrightness = unsafeBitCast(getSymbol, to: GetBrightness.self)
let setBrightness = unsafeBitCast(setSymbol, to: SetBrightness.self)
func readBrightness() -> Float {
    var value: Float = 0
    guard getBrightness(display, &value) == 0, value.isFinite, (0...1).contains(value) else {
        fail("내장 디스플레이 밝기를 읽지 못했습니다.")
    }
    return value
}

if arguments[0] == "set" {
    let desired = Float(Int(arguments[1])!) / 100
    guard setBrightness(display, desired) == 0 else { fail("화면 밝기 변경에 실패했습니다.") }
    guard abs(readBrightness() - desired) <= 0.015 else {
        fail("변경한 밝기를 확인하지 못했습니다.")
    }
}
print(Int((readBrightness() * 100).rounded()))
