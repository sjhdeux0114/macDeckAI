import Foundation

// Official Microsoft installers, pinned to the Winetricks upstream source snapshot
// inspected 2026-10-19. No downloaded script or game-supplied command is executed.
struct DependencyPackage: Codable, Hashable {
    let id: String
    let family: String
    let architecture: String
    let url: String
    let sha256: String
    var label: String {
        let net = ["dotnet35sp1":".NET Framework 2.0–3.5 SP1", "dotnet40":".NET Framework 4.0", "dotnet45":".NET Framework 4.5", "dotnet462":".NET Framework 4.6.2", "dotnet472":".NET Framework 4.7.2", "dotnet48":".NET Framework 4.8"]
        return (net[family] ?? (family == "vcrun2022" ? "Visual C++ 2015–2022" : family.replacingOccurrences(of: "vcrun", with: "Visual C++ "))) + " · " + (architecture == "both" ? "x86/x64" : architecture)
    }
    // Legacy wrappers use the exact quiet syntax of the pinned upstream packages.
    var arguments: [String] {
        if ["vcrun2005", "vcrun2008"].contains(family) { return ["/q"] }
        if family == "dotnet40" { return ["/q", "/c:install.exe /q"] }
        return ["/q", "/norestart"]
    }
    var isCLR: Bool { family.hasPrefix("dotnet") }
}
enum DependencyCatalog {
    static let packages: [DependencyPackage] = [
        DependencyPackage(id: "vc2005-x86", family: "vcrun2005", architecture: "x86", url: "https://download.microsoft.com/download/8/B/4/8B42259F-5D70-43F4-AC2E-4B208FD8D66A/vcredist_x86.EXE", sha256: "8648c5fc29c44b9112fe52f9a33f80e7fc42d10f3b5b42b2121542a13e44adfd"),
        DependencyPackage(id: "vc2005-x64", family: "vcrun2005", architecture: "x64", url: "https://download.microsoft.com/download/8/B/4/8B42259F-5D70-43F4-AC2E-4B208FD8D66A/vcredist_x64.EXE", sha256: "4487570bd86e2e1aac29db2a1d0a91eb63361fcaac570808eb327cd4e0e2240d"),
        DependencyPackage(id: "vc2008-x86", family: "vcrun2008", architecture: "x86", url: "https://download.microsoft.com/download/5/D/8/5D8C65CB-C849-4025-8E95-C3966CAFD8AE/vcredist_x86.exe", sha256: "8742bcbf24ef328a72d2a27b693cc7071e38d3bb4b9b44dec42aa3d2c8d61d92"),
        DependencyPackage(id: "vc2008-x64", family: "vcrun2008", architecture: "x64", url: "https://download.microsoft.com/download/5/D/8/5D8C65CB-C849-4025-8E95-C3966CAFD8AE/vcredist_x64.exe", sha256: "c5e273a4a16ab4d5471e91c7477719a2f45ddadb76c7f98a38fa5074a6838654"),
        DependencyPackage(id: "vc2010-x86", family: "vcrun2010", architecture: "x86", url: "https://download.microsoft.com/download/5/B/C/5BC5DBB3-652D-4DCE-B14A-475AB85EEF6E/vcredist_x86.exe", sha256: "31d32fa39d52cac9a765a43660431f7a127eee784b54b2f5e2af3e2b763a1af8"),
        DependencyPackage(id: "vc2010-x64", family: "vcrun2010", architecture: "x64", url: "https://download.microsoft.com/download/A/8/0/A80747C3-41BD-45DF-B505-E9710D2744E0/vcredist_x64.exe", sha256: "2fddbc3aaaab784c16bc673c3bae5f80929d5b372810dbc28649283566d33255"),
        DependencyPackage(id: "vc2012-x86", family: "vcrun2012", architecture: "x86", url: "https://download.microsoft.com/download/1/6/B/16B06F60-3B20-4FF2-B699-5E9B7962F9AE/VSU_4/vcredist_x86.exe", sha256: "b924ad8062eaf4e70437c8be50fa612162795ff0839479546ce907ffa8d6e386"),
        DependencyPackage(id: "vc2012-x64", family: "vcrun2012", architecture: "x64", url: "https://download.microsoft.com/download/1/6/B/16B06F60-3B20-4FF2-B699-5E9B7962F9AE/VSU_4/vcredist_x64.exe", sha256: "681be3e5ba9fd3da02c09d7e565adfa078640ed66a0d58583efad2c1e3cc4064"),
        DependencyPackage(id: "vc2013-x86", family: "vcrun2013", architecture: "x86", url: "https://download.microsoft.com/download/0/5/6/056dcda9-d667-4e27-8001-8a0c6971d6b1/vcredist_x86.exe", sha256: "89f4e593ea5541d1c53f983923124f9fd061a1c0c967339109e375c661573c17"),
        DependencyPackage(id: "vc2013-x64", family: "vcrun2013", architecture: "x64", url: "https://download.microsoft.com/download/0/5/6/056dcda9-d667-4e27-8001-8a0c6971d6b1/vcredist_x64.exe", sha256: "20e2645b7cd5873b1fa3462b99a665ac8d6e14aae83ded9d875fea35ffdd7d7e"),
        DependencyPackage(id: "vc2022-x86", family: "vcrun2022", architecture: "x86", url: "https://aka.ms/vs/17/release/vc_redist.x86.exe", sha256: "0c09f2611660441084ce0df425c51c11e147e6447963c3690f97e0b25c55ed64"),
        DependencyPackage(id: "vc2022-x64", family: "vcrun2022", architecture: "x64", url: "https://aka.ms/vs/17/release/vc_redist.x64.exe", sha256: "cc0ff0eb1dc3f5188ae6300faef32bf5beeba4bdd6e8e445a9184072096b713b"),
        DependencyPackage(id: "dotnet35sp1", family: "dotnet35sp1", architecture: "both", url: "https://download.microsoft.com/download/2/0/e/20e90413-712f-438c-988e-fdaa79a8ac3d/dotnetfx35.exe", sha256: "0582515bde321e072f8673e829e175ed2e7a53e803127c50253af76528e66bc1"),
        DependencyPackage(id: "dotnet40", family: "dotnet40", architecture: "both", url: "https://download.microsoft.com/download/9/5/A/95A9616B-7A37-4AF6-BC36-D6EA96C8DAAE/dotNetFx40_Full_x86_x64.exe", sha256: "65e064258f2e418816b304f646ff9e87af101e4c9552ab064bb74d281c38659f"),
        DependencyPackage(id: "dotnet45", family: "dotnet45", architecture: "both", url: "https://download.microsoft.com/download/b/a/4/ba4a7e71-2906-4b2d-a0e1-80cf16844f5f/dotnetfx45_full_x86_x64.exe", sha256: "a04d40e217b97326d46117d961ec4eda455e087b90637cb33dd6cc4a2c228d83"),
        DependencyPackage(id: "dotnet462", family: "dotnet462", architecture: "both", url: "https://download.visualstudio.microsoft.com/download/pr/8e396c75-4d0d-41d3-aea8-848babc2736a/80b431456d8866ebe053eb8b81a168b3/NDP462-KB3151800-x86-x64-AllOS-ENU.exe", sha256: "b4cbb4bc9a3983ec3be9f80447e0d619d15256a9ce66ff414ae6e3856705e237"),
        DependencyPackage(id: "dotnet472", family: "dotnet472", architecture: "both", url: "https://download.visualstudio.microsoft.com/download/pr/1f5af042-d0e4-4002-9c59-9ba66bcf15f6/089f837de42708daacaae7c04b7494db/NDP472-KB4054530-x86-x64-AllOS-ENU.exe", sha256: "5cb624b97f9fd6d3895644c52231c9471cd88aacb57d6e198d3024a1839139f6"),
        DependencyPackage(id: "dotnet48", family: "dotnet48", architecture: "both", url: "https://download.visualstudio.microsoft.com/download/pr/7afca223-55d2-470a-8edc-6a1739ae3252/abd170b4b0ec15ad0222a809b761a036/ndp48-x86-x64-allos-enu.exe", sha256: "95889d6de3f2070c07790ad6cf2000d33d9a1bdfc6a381725ab82ab1c314fd53"),
    ]
    static func package(_ id: String) -> DependencyPackage? { packages.first { $0.id == id } }
}
