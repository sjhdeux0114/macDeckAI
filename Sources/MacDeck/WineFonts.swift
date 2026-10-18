import Foundation

/// Uses the font already licensed and installed on this Mac; never bundles Apple fonts.
enum WineFonts {
    static func prepare(prefix: URL, wine: String) throws {
        let fm = FileManager.default
        let source = URL(fileURLWithPath: "/System/Library/Fonts/AppleSDGothicNeo.ttc")
        guard fm.fileExists(atPath: source.path) else { return }
        let fonts = prefix.appendingPathComponent("drive_c/windows/Fonts")
        try fm.createDirectory(at: fonts, withIntermediateDirectories: true)
        let link = fonts.appendingPathComponent("MacDeckKorean.ttc")
        if !fm.fileExists(atPath: link.path) {
            try fm.createSymbolicLink(at: link, withDestinationURL: source)
        }
        let marker = prefix.appendingPathComponent(".macdeck-korean-fonts-v1")
        guard !fm.fileExists(atPath: marker.path) else { return }
        let registry = """
        Windows Registry Editor Version 5.00

        [HKEY_LOCAL_MACHINE\\Software\\Microsoft\\Windows NT\\CurrentVersion\\Fonts]
        "Apple SD Gothic Neo (TrueType)"="MacDeckKorean.ttc"

        [HKEY_CURRENT_USER\\Software\\Wine\\Fonts\\Replacements]
        "Malgun Gothic"="Apple SD Gothic Neo"
        "Gulim"="Apple SD Gothic Neo"
        "Dotum"="Apple SD Gothic Neo"

        [HKEY_LOCAL_MACHINE\\Software\\Microsoft\\Windows NT\\CurrentVersion\\FontLink\\SystemLink]
        "Tahoma"=hex(7):\(fontLinkBytes)
        "Arial"=hex(7):\(fontLinkBytes)
        "Segoe UI"=hex(7):\(fontLinkBytes)
        "Microsoft Sans Serif"=hex(7):\(fontLinkBytes)

        """
        let regFile = prefix.appendingPathComponent("drive_c/macdeck-korean-fonts.reg")
        var bytes = Data([0xff, 0xfe]); bytes.append(registry.data(using: .utf16LittleEndian)!)
        try bytes.write(to: regFile, options: .atomic)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: wine)
        process.arguments = ["regedit.exe", "/S", "C:\\macdeck-korean-fonts.reg"]
        var environment = ProcessInfo.processInfo.environment
        environment["WINEPREFIX"] = prefix.path; environment["WINEDEBUG"] = "-all"
        environment["WINEDLLOVERRIDES"] = "winemenubuilder.exe=d;winedbg.exe=d"
        let runtime = URL(fileURLWithPath: wine).resolvingSymlinksInPath()
            .deletingLastPathComponent().deletingLastPathComponent()
        environment["DYLD_FALLBACK_LIBRARY_PATH"] = runtime.appendingPathComponent("lib").path
            + ":" + runtime.appendingPathComponent("Media/lib").path
        process.environment = environment
        process.standardOutput = FileHandle.nullDevice; process.standardError = FileHandle.nullDevice
        try process.run()
        let deadline = Date().addingTimeInterval(10)
        while process.isRunning && Date() < deadline { Thread.sleep(forTimeInterval: 0.05) }
        guard !process.isRunning else { process.terminate(); throw DeckError.message("한글 글꼴 등록 대기 시간이 초과됐습니다. Steam을 종료하고 다시 실행해 주세요.") }
        guard process.terminationStatus == 0 else { throw DeckError.message("Windows 환경의 한글 글꼴 등록에 실패했습니다.") }
        try Data("local Apple SD Gothic Neo fallback v1\n".utf8).write(to: marker, options: .atomic)
    }

    private static var fontLinkBytes: String {
        ("MacDeckKorean.ttc,Apple SD Gothic Neo\0\0".data(using: .utf16LittleEndian) ?? Data())
            .map { String(format: "%02x", $0) }.joined(separator: ",")
    }
}
