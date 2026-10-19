import Foundation

/// Reads bounded PE tables only; never loads a game or executes an imported DLL.
enum PEDependencies {
    static func requirements(file: URL) -> Set<String> {
        guard let input = try? FileHandle(forReadingFrom: file) else { return [] }
        defer { try? input.close() }
        let length = (try? input.seekToEnd()) ?? 0
        func read(_ offset: UInt64, _ count: Int) -> Data {
            guard count >= 0, offset <= length, UInt64(count) <= length - offset else { return Data() }
            do { try input.seek(toOffset: offset); return try input.read(upToCount: count) ?? Data() } catch { return Data() }
        }
        func u32(_ b: Data, _ o: Int) -> UInt32 { guard o >= 0, o+4 <= b.count else { return 0 }; return (0..<4).reduce(UInt32(0)) { $0 | UInt32(b[o+$1]) << ($1*8) } }
        func u16(_ b: Data, _ o: Int) -> Int { guard o >= 0, o+2 <= b.count else { return 0 }; return Int(b[o]) | Int(b[o+1]) << 8 }
        let dos = read(0,64)
        guard dos.starts(with: [0x4d,0x5a]) else { return [] }
        let pe = UInt64(u32(dos,60)), header = read(pe,24)
        guard header.starts(with: [0x50,0x45,0,0]) else { return [] }
        let machine = u16(header,4), count = u16(header,6), optionalSize = u16(header,20)
        guard [0x14c,0x8664].contains(machine), count > 0, count <= 96, optionalSize >= 96, optionalSize <= 4096 else { return [] }
        let optional = read(pe+24,optionalSize), magic = u16(optional,0)
        guard magic == 0x10b || magic == 0x20b else { return [] }
        let directory = magic == 0x10b ? 96 : 112
        let sections = read(pe+24+UInt64(optionalSize),count*40)
        func offset(_ rva: UInt32) -> UInt64? {
            for i in 0..<count {
                let va = UInt64(u32(sections,i*40+12)), rawSize = UInt64(u32(sections,i*40+16)), raw = UInt64(u32(sections,i*40+20))
                if UInt64(rva) >= va && UInt64(rva)-va < rawSize {
                    let result = raw+UInt64(rva)-va
                    return result < length ? result : nil
                }
            }
            return nil
        }
        func name(_ rva: UInt32) -> String? {
            guard let o = offset(rva) else { return nil }
            let bytes = read(o,Int(min(128,length-o)))
            guard let end = bytes.firstIndex(of: 0) else { return nil }
            return String(data: bytes.prefix(upTo: end),encoding: .ascii)?.lowercased()
        }
        let arch = machine == 0x14c ? "x86" : "x64"
        var found = Set<String>()
        func add(_ name: String?) {
            guard let name else { return }
            let versions = [("80","2005"),("90","2008"),("100","2010"),("110","2012"),("120","2013"),("140","2022")]
            for (number,year) in versions where ["msvcr"+number+".dll", "msvcp"+number+".dll", "vcruntime"+number+".dll", "vcruntime"+number+"_1.dll", "msvcp"+number+"_1.dll", "msvcp"+number+"_2.dll"].contains(name) { found.insert("vc"+year+"-"+arch) }
        }
        if let start = offset(u32(optional,directory+8)) {
            for i in 0..<256 {
                let descriptor = read(start+UInt64(i*20),20)
                guard descriptor.count == 20, descriptor.contains(where: { $0 != 0 }) else { break }
                add(name(u32(descriptor,12)))
            }
        }
        // Delay import names are RVAs when dlattrRva is set.
        if let start = offset(u32(optional,directory+13*8)) {
            for i in 0..<256 {
                let descriptor = read(start+UInt64(i*32),32)
                guard descriptor.count == 32, descriptor.contains(where: { $0 != 0 }) else { break }
                if u32(descriptor,0) & 1 != 0 { add(name(u32(descriptor,4))) }
            }
        }
        // Unity/Mono managed DLL metadata does not imply Windows .NET is needed.
        // Only a CLR entry executable is sufficient static evidence for activation.
        if file.pathExtension.lowercased() == "exe", let clr = offset(u32(optional,directory+14*8)) {
            let header = read(clr,24)
            if let metadata = offset(u32(header,8)) {
                let data = read(metadata,128)
                if data.count >= 16, data.starts(with: [0x42,0x53,0x4a,0x42]), let text = String(data: data[16..<min(data.count,64)],encoding: .ascii) {
                    if text.hasPrefix("v4.") { found.insert("dotnet40") }
                    else if text.hasPrefix("v2.") { found.insert("dotnet35sp1") }
                }
            }
        }
        return found
    }
    static func requirements(in root: URL) -> Set<String> {
        var found = Set<String>(), inspected = 0
        func scan(_ folder: URL, depth: Int) {
            guard depth <= 4, inspected < 512, let files = try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.isDirectoryKey,.isSymbolicLinkKey], options: .skipsHiddenFiles) else { return }
            for file in files.sorted(by: { $0.path < $1.path }).prefix(512) {
                guard inspected < 512, let values = try? file.resourceValues(forKeys: [.isDirectoryKey,.isSymbolicLinkKey]), values.isSymbolicLink != true else { continue }
                if values.isDirectory == true {
                    if !["redist","_commonredist","directx","easyanticheat","monobleedingedge","mono","managed","dotnet"].contains(file.lastPathComponent.lowercased()) { scan(file, depth: depth+1) }
                } else if ["exe","dll"].contains(file.pathExtension.lowercased()) {
                    inspected += 1; found.formUnion(requirements(file: file))
                }
            }
        }
        scan(root,depth: 0); return found
    }
}
