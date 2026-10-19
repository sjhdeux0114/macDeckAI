import Foundation

struct CompatibilityFinding: Codable {
    var id: String
    var title: String
    var detail: String
    var sources: [String]
}
struct CompatibilityReport: Codable {
    var schema = 1
    var game: String
    var engines: [String]
    var evidence: [String]
    var graphicsImports: [String]
    var architectures: [String]
    var scanTruncated: Bool
    var findings: [CompatibilityFinding]
    var validation = "정적 점검 결과입니다. 실제 게임 실행 또는 Metal 가속 성공을 보장하지 않습니다."
}

enum CompatibilityInspector {
    static let unitySource = "https://docs.unity3d.com/6000.0/Documentation/Manual/PlayerCommandLineArguments.html"
    static let unrealSource = "https://dev.epicgames.com/documentation/en-us/unreal-engine/hardware-and-software-specifications-for-unreal-engine"
    static let antiCheatSource = "https://partner.steamgames.com/doc/steamhardware/proton"

    static func inspect(game: Game) -> CompatibilityReport {
        guard let root = DirectX12Support.targetDirectory(for: game) else {
            return report(game: game.name, files: [], imports: [], architectures: [], truncated: false)
        }
        let fm = FileManager.default
        var files: [String] = [], imports = Set<String>(), architectures = Set<String>()
        if let enumerator = fm.enumerator(at: root, includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey], options: [.skipsHiddenFiles]) {
            var visited = 0, exeCount = 0
            while let url = enumerator.nextObject() as? URL {
                visited += 1
                if visited > 2500 { return report(game: game.name, files: files, imports: Array(imports), architectures: Array(architectures), truncated: true) }
                let relative = String(url.path.dropFirst(root.path.count + 1))
                let parts = relative.split(separator: "/")
                let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
                if values?.isSymbolicLink == true { enumerator.skipDescendants(); continue }
                if values?.isDirectory == true {
                    if parts.count >= 5 || ["redist", "_commonredist", "node_modules", "cache"].contains(url.lastPathComponent.lowercased()) { enumerator.skipDescendants() }
                    continue
                }
                files.append(relative)
                if url.pathExtension.lowercased() == "exe", exeCount < 12,
                   !url.lastPathComponent.lowercased().contains("crash"), !url.lastPathComponent.lowercased().contains("setup") {
                    exeCount += 1
                    let pe = peImports(url)
                    imports.formUnion(pe.imports)
                    if let architecture = pe.architecture { architectures.insert(architecture) }
                }
            }
        }
        return report(game: game.name, files: files, imports: Array(imports), architectures: Array(architectures), truncated: false)
    }

    static func report(game: String, files: [String], imports: [String], architectures: [String], truncated: Bool) -> CompatibilityReport {
        let lower = files.map { $0.lowercased() }
        var engines: [String] = [], evidence: [String] = [], findings: [CompatibilityFinding] = []
        func add(_ id: String, _ title: String, _ detail: String, _ sources: [String]) {
            findings.append(CompatibilityFinding(id: id, title: title, detail: detail, sources: sources))
        }
        func engine(_ name: String, matching predicate: (String) -> Bool) -> Bool {
            let hits = zip(files, lower).filter { predicate($0.1) }.map { $0.0 }
            if !hits.isEmpty { engines.append(name); evidence += hits.prefix(4) }
            return !hits.isEmpty
        }
        if engine("Unity", matching: { $0.hasSuffix("unityplayer.dll") || $0.hasSuffix("/globalgamemanagers") }) {
            add("unity-renderer", "Unity 렌더러 선택 확인", "-force-d3d11/12는 해당 그래픽 API로 빌드된 게임에서만 시험하세요. 셰이더 누락·검은 화면은 Unity 버전과 Player.log로 확인합니다. CrashHandler 차단은 게임 크래시의 해결책이 아닙니다.", [unitySource])
        }
        if engine("Unreal", matching: { $0.hasSuffix("-win64-shipping.exe") || $0.hasSuffix("-win32-shipping.exe") }) {
            add("unreal-rhi", "Unreal RHI/SM6 요구 확인", "UE5 Nanite 등은 DX12/SM6 기능이 필요할 수 있습니다. DX11을 모든 UE 게임에 강제하지 않습니다. VC++ 전제조건과 Agility SDK DLL 누락을 먼저 확인하세요.", [unrealSource])
        }
        if engine("CryEngine", matching: { ["crysystem.dll", "crygame.dll", "cryengine.cryengine"].contains(URL(fileURLWithPath: $0).lastPathComponent) }) {
            add("cry-renderer", "CryEngine 렌더러·셰이더 캐시 확인", "r_Driver 지원과 셰이더 캐시는 배포된 엔진 버전에 따라 다릅니다. Vulkan/DX11 전환이나 캐시 삭제를 일괄 적용하지 않습니다.", ["https://www.cryengine.com/docs/static/engines/cryengine-5/categories/23756816/pages/27594203"])
        }
        if engine("Cocos", matching: { ["libcocos2d.dll", "cocos2d.dll", "cocos2d-jsb.dll"].contains(URL(fileURLWithPath: $0).lastPathComponent) }) {
            add("cocos-backend", "Cocos 버전·OpenGL/GLES 경로 확인", "Cocos2d-x와 Creator의 렌더러는 다릅니다. Windows OpenGL 게임에 DX11 인자를 넣어 Metal로 바뀐다고 가정하지 않습니다. 네이티브 Metal 지원과 Windows 빌드의 실제 API를 구분하세요.", ["https://docs.cocos.com/creator/3.8/manual/en/graphics-backend/overview.html", "https://github.com/cocos2d/cocos2d-x/blob/v4/CHANGELOG"])
        }
        if engine("Godot 후보", matching: { $0.hasSuffix(".pck") }) {
            add("godot-renderer", "Godot 후보: 패키지 단서만 확인", ".pck만으로 엔진을 확정할 수 없습니다. Forward+/Mobile/Compatibility 렌더러가 요구하는 API가 달라 일괄 DX11 전환은 하지 않습니다.", ["https://docs.godotengine.org/en/stable/tutorials/rendering/renderers.html"])
        }
        if engine("RE Engine", matching: { ["re3.exe", "devilmaycry5.exe"].contains(URL(fileURLWithPath: $0).lastPathComponent) }) {
            add("re-media-gpu", "RE Engine 영상·GPU 경로 확인", "RE3/DMC5에서 로컬 영상 의존성 및 DXMT GS/TS 이력을 확인했습니다. 다른 RE 게임 전체의 해결을 의미하지 않습니다. 영상 생성 실패와 GPU timeout을 구분하세요.", ["https://github.com/3Shain/dxmt/issues/200", "https://github.com/l00sed/re-engine-macos"])
        }
        if lower.contains(where: { $0.contains("easyanticheat") || $0.contains("battleye") || $0.hasSuffix("/beservice.exe") }) {
            add("anticheat", "안티치트 호환성 확인 필요", "Proton 지원은 개발사의 활성화가 필요하며 Linux 지원이 macOS Wine 지원을 뜻하지 않습니다. 안티치트 DLL을 차단해 호환 문제를 해결할 수 없습니다.", [antiCheatSource])
        }
        let api = Set(imports.map { $0.lowercased() })
        if api.contains("d3d9.dll") {
            add("d3d9-device", "DX9 장치 손실·32비트 제약", "DX9는 엔진이 아니라 그래픽 API입니다. 창 전환 뒤 device lost/reset과 32비트 주소 공간을 점검하세요. Vulkan 선택만으로 실제 GPU 가속 성공을 단정하지 않습니다.", ["https://learn.microsoft.com/en-us/windows/win32/direct3d9/lost-devices"])
        }
        if api.contains("d3d12.dll") {
            add("d3d12-capabilities", "DX12 실제 기능 지원 확인", "기능 수준을 환경 변수로 높여도 구현되지 않은 기능이 생기지 않습니다. DXMT 전역 DX11 모드는 DX12 게임 변환기가 아닙니다. VkDevice lost는 GPU 오류 로그로 확인하세요.", [unrealSource, "https://github.com/HansKristian-Work/vkd3d-proton/blob/master/README.md"])
        }
        if api.contains("opengl32.dll") {
            add("opengl-path", "OpenGL 경로 확인", "OpenGL 로딩만으로 CPU 렌더링이라고 판단하지 않습니다. 실제 renderer/driver와 프레임 로그가 필요합니다. DXMT는 OpenGL 변환기가 아닙니다.", ["https://docs.cocos.com/creator/3.8/manual/en/graphics-backend/overview.html"])
        }
        if lower.contains(where: { ["dinput8.dll", "dxgi.dll", "version.dll", "winmm.dll"].contains(URL(fileURLWithPath: $0).lastPathComponent) }) {
            add("native-proxy", "동봉 프록시·모드 DLL 확인", "입력/그래픽/로더 DLL은 모드 또는 정식 게임 구성요소일 수 있습니다. builtin 강제와 충돌할 수 있지만 파일을 자동 삭제하거나 무조건 native로 바꾸지 않습니다.", ["https://github.com/wine-mirror/wine/blob/master/loader/wine.man.in"])
        }
        if truncated { add("scan-limit", "검사 범위 제한", "최대 2500개 항목·5단계 깊이만 검사했습니다. 동적 DLL 로딩과 정적 링크 엔진은 감지하지 못할 수 있습니다.", []) }
        return CompatibilityReport(game: game, engines: engines.sorted(), evidence: evidence.sorted(), graphicsImports: api.sorted(), architectures: architectures.sorted(), scanTruncated: truncated, findings: findings)
    }

    // Bounded PE import parsing: headers, descriptors and short DLL names only.
    static func peImports(_ url: URL) -> (architecture: String?, imports: [String]) {
        guard let f = try? FileHandle(forReadingFrom: url) else { return (nil, []) }
        defer { try? f.close() }
        func read(_ offset: UInt64, _ count: Int) -> Data {
            guard (try? f.seek(toOffset: offset)) != nil else { return Data() }
            return (try? f.read(upToCount: count)) ?? Data()
        }
        func u16(_ d: Data, _ o: Int) -> UInt16 { UInt16(d[o]) | UInt16(d[o+1]) << 8 }
        func u32(_ d: Data, _ o: Int) -> UInt32 { (0..<4).reduce(0) { $0 | UInt32(d[o+$1]) << ($1*8) } }
        let dos = read(0,64)
        guard dos.count == 64, dos.prefix(2) == Data([0x4d,0x5a]) else { return (nil,[]) }
        let p = Int(u32(dos,60)); guard p >= 64 && p < 0x10000 else { return (nil,[]) }
        let h = read(UInt64(p),24); guard h.count == 24, h.prefix(4) == Data([0x50,0x45,0,0]) else { return (nil,[]) }
        let machine=u16(h,4), n=Int(u16(h,6)), os=Int(u16(h,20))
        let arch = machine == 0x14c ? "x86" : machine == 0x8664 ? "x86_64" : "other"
        guard n > 0 && n <= 96 && os >= 112 && os <= 512 else { return (arch,[]) }
        let opt = read(UInt64(p+24),os)
        guard opt.count == os else { return (arch,[]) }
        let magic = u16(opt,0), directory = magic == 0x20b ? 112 : 96
        guard (magic == 0x20b || magic == 0x10b) && os >= directory+16 else { return (arch,[]) }
        let table=read(UInt64(p+24+os),n*40); guard table.count == n*40 else { return (arch,[]) }
        func fileOffset(_ rva: UInt32) -> UInt64? {
            for i in 0..<n {
                let o=i*40, va=u32(table,o+12), size=u32(table,o+16), raw=u32(table,o+20)
                if rva >= va && UInt64(rva)-UInt64(va) < UInt64(size) { return UInt64(raw)+UInt64(rva-va) }
            }
            return nil
        }
        guard let start=fileOffset(u32(opt,directory+8)) else { return (arch,[]) }
        var imports: [String] = []
        for i in 0..<128 {
            let descriptor=read(start+UInt64(i*20),20)
            guard descriptor.count == 20 && descriptor.contains(where: { $0 != 0 }) else { break }
            guard let name=fileOffset(u32(descriptor,12)) else { break }
            let bytes=read(name,96).prefix(while: { $0 != 0 })
            guard let text=String(data: Data(bytes), encoding:.ascii), text.lowercased().hasSuffix(".dll") else { continue }
            if ["d3d9.dll","d3d11.dll","d3d12.dll","dxgi.dll","opengl32.dll","vulkan-1.dll"].contains(text.lowercased()) { imports.append(text.lowercased()) }
        }
        return (arch, imports)
    }
}
