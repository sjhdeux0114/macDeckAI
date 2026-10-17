import Foundation
import Virtualization
import Metal
import Darwin

enum ProbeError: Error, CustomStringConvertible {
    case message(String)
    var description: String { switch self { case .message(let value): return value } }
}

func hostReport() throws {
    var report: [String: Any] = [
        "os": ProcessInfo.processInfo.operatingSystemVersionString,
        "cpuCount": ProcessInfo.processInfo.processorCount,
        "memoryBytes": ProcessInfo.processInfo.physicalMemory,
        "hostPageBytes": getpagesize(),
        "virtualizationSupported": VZVirtualMachine.isSupported,
        "linuxGuestGPUAcceleration": "unverified; Metal availability does not prove Linux Vulkan support",
        "steamExecution": "not tested",
        "protonExecution": "not tested"
    ]
    #if arch(arm64)
    report["architecture"] = "arm64"
    #else
    report["architecture"] = "x86_64"
    #endif
    if let device = MTLCreateSystemDefaultDevice() {
        report["metalDevice"] = device.name
        let source = """
        #include <metal_stdlib>
        using namespace metal;
        kernel void proof(device uint *values [[buffer(0)]], uint i [[thread_position_in_grid]]) {
            values[i] = i * 3 + 7;
        }
        """
        let library = try device.makeLibrary(source: source, options: nil)
        guard let function = library.makeFunction(name: "proof"),
              let queue = device.makeCommandQueue(),
              let buffer = device.makeBuffer(length: 256 * MemoryLayout<UInt32>.stride, options: .storageModeShared),
              let command = queue.makeCommandBuffer(),
              let encoder = command.makeComputeCommandEncoder() else {
            throw ProbeError.message("Cannot create Metal compute resources")
        }
        let pipeline = try device.makeComputePipelineState(function: function)
        encoder.setComputePipelineState(pipeline)
        encoder.setBuffer(buffer, offset: 0, index: 0)
        encoder.dispatchThreads(MTLSize(width: 256, height: 1, depth: 1), threadsPerThreadgroup: MTLSize(width: min(256, pipeline.maxTotalThreadsPerThreadgroup), height: 1, depth: 1))
        encoder.endEncoding()
        command.commit()
        command.waitUntilCompleted()
        if let error = command.error { throw error }
        let values = buffer.contents().bindMemory(to: UInt32.self, capacity: 256)
        let passed = command.status == .completed && (0..<256).allSatisfy { values[$0] == UInt32($0 * 3 + 7) }
        report["metalComputePassed"] = passed
        if !passed { throw ProbeError.message("Metal compute returned incorrect data") }
    } else {
        report["metalComputePassed"] = false
        report["metalDevice"] = NSNull()
    }
    let data = try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
    print(String(decoding: data, as: UTF8.self))
}

final class LinuxProbe: NSObject, VZVirtualMachineDelegate {
    private var machine: VZVirtualMachine!
    private let output = Pipe()
    private let input = Pipe()
    private var transcript = ""
    private var completed = false
    private var timeout: DispatchWorkItem?
    private let nonce = UUID().uuidString

    func boot(kernel: String, initrd: String) throws {
        guard VZVirtualMachine.isSupported else { throw ProbeError.message("Virtualization is unavailable on this host") }
        for path in [kernel, initrd] {
            guard FileManager.default.isReadableFile(atPath: path) else { throw ProbeError.message("Missing readable boot artifact: \(path)") }
        }
        let config = VZVirtualMachineConfiguration()
        let loader = VZLinuxBootLoader(kernelURL: URL(fileURLWithPath: kernel))
        loader.initialRamdiskURL = URL(fileURLWithPath: initrd)
        loader.commandLine = "console=hvc0 rdinit=/macdeck-init panic=-1 macdeck_nonce=\(nonce)"
        config.bootLoader = loader
        config.platform = VZGenericPlatformConfiguration()
        config.cpuCount = 2
        config.memorySize = 512 * 1024 * 1024
        config.entropyDevices = [VZVirtioEntropyDeviceConfiguration()]
        let graphics = VZVirtioGraphicsDeviceConfiguration()
        graphics.scanouts = [VZVirtioGraphicsScanoutConfiguration(widthInPixels: 1280, heightInPixels: 800)]
        config.graphicsDevices = [graphics]
        let console = VZVirtioConsoleDeviceSerialPortConfiguration()
        console.attachment = VZFileHandleSerialPortAttachment(fileHandleForReading: input.fileHandleForReading, fileHandleForWriting: output.fileHandleForWriting)
        config.serialPorts = [console]
        // The guest receives only a virtual display; no storage, network or host directories.
        try config.validate()
        machine = VZVirtualMachine(configuration: config)
        machine.delegate = self
        output.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            FileHandle.standardOutput.write(data)
            DispatchQueue.main.async { self?.consume(String(decoding: data, as: UTF8.self)) }
        }
        let deadline = DispatchWorkItem { [weak self] in self?.finish(code: 2, message: "FAIL: guest proof timed out after 45 seconds") }
        timeout = deadline
        DispatchQueue.main.asyncAfter(deadline: .now() + 45, execute: deadline)
        machine.start { [weak self] result in
            if case .failure(let error) = result { self?.finish(code: 2, message: "FAIL: VM start: \(error)") }
        }
    }

    private func consume(_ text: String) {
        transcript += text
        let required = ["MACDECK_KERNEL=Linux", "MACDECK_ARCH=aarch64", "MACDECK_PROC=mounted", "MACDECK_SYS=mounted", "MACDECK_DONE=\(nonce)"]
        if required.allSatisfy({ transcript.contains($0) }) {
            finish(code: 0, message: "PASS: ARM64 Linux kernel and userland executed inside Apple's Virtualization framework. Steam/Proton/GPU acceleration remain untested.")
        }
    }

    private func finish(code: Int32, message: String) {
        guard !completed else { return }
        completed = true
        timeout?.cancel()
        output.fileHandleForReading.readabilityHandler = nil
        print("\n\(message)")
        fflush(stdout)
        if machine?.canStop == true {
            machine.stop { error in
                if let error { fputs("VM stop: \(error)\n", stderr) }
                exit(code)
            }
        } else { exit(code) }
    }

    func virtualMachine(_ virtualMachine: VZVirtualMachine, didStopWithError error: Error) {
        finish(code: 2, message: "FAIL: guest stopped: \(error)")
    }
    func guestDidStop(_ virtualMachine: VZVirtualMachine) {
        finish(code: 2, message: "FAIL: guest stopped before all proof markers arrived")
    }
}

let args = Array(CommandLine.arguments.dropFirst())
var activeProbe: LinuxProbe?
do {
    switch args.first {
    case "host": try hostReport()
    case "linux":
        guard args.count == 3 else { throw ProbeError.message("usage: macdeck-probe linux KERNEL INITRD") }
        let probe = LinuxProbe()
        activeProbe = probe
        try probe.boot(kernel: args[1], initrd: args[2])
        RunLoop.main.run()
    default: throw ProbeError.message("usage: macdeck-probe host | linux KERNEL INITRD")
    }
} catch {
    fputs("\(error)\n", stderr)
    exit(2)
}
