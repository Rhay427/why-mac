import Darwin
import Foundation

struct ProcessFootprint {
    let bytes: UInt64
    let startTime: UInt64
}

struct MemorySensor {
    func read(pressure: () -> MemoryPressureState,
              vmLookup: () -> MemoryVMStatistics? = Self.readVMStatistics,
              processLookup: () -> [ProcessMemorySnapshot] = Self.readProcesses) -> MemorySnapshot {
        let initial = pressure()
        guard initial.isElevated else { return MemorySnapshot(pressure: initial) }
        let vm = vmLookup()
        let processes = processLookup()
        let current = pressure()
        // A recovery event during collection must not leave a stale warning.
        guard current.isElevated else { return MemorySnapshot(pressure: current) }
        return MemorySnapshot(pressure: current, physicalMemory: ProcessInfo.processInfo.physicalMemory,
                              vm: vm, processes: processes)
    }

    static func readVMStatistics() -> MemoryVMStatistics? {
        let host = mach_host_self()
        defer { mach_port_deallocate(mach_task_self_, host) }
        var pageSize: vm_size_t = 0
        var vm = vm_statistics64_data_t()
        var count = mach_msg_type_number_t(MemoryLayout.size(ofValue: vm) / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &vm) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(host, HOST_VM_INFO64, $0, &count)
            }
        }
        guard result == KERN_SUCCESS, host_page_size(host, &pageSize) == KERN_SUCCESS else { return nil }
        var swap = xsw_usage()
        var size = MemoryLayout.size(ofValue: swap)
        let swapResult = sysctlbyname("vm.swapusage", &swap, &size, nil, 0)
        return MemoryVMStatistics(pageSize: UInt64(pageSize), freePages: UInt64(vm.free_count),
            activePages: UInt64(vm.active_count), inactivePages: UInt64(vm.inactive_count),
            wiredPages: UInt64(vm.wire_count), compressorPages: UInt64(vm.compressor_page_count),
            pageIns: vm.pageins, pageOuts: vm.pageouts, compressions: vm.compressions,
            decompressions: vm.decompressions, swapIns: vm.swapins, swapOuts: vm.swapouts,
            swapUsedBytes: swapResult == 0 ? swap.xsu_used : nil)
    }

    static func readFootprint(pid: pid_t) -> ProcessFootprint? {
        var info = rusage_info_v2()
        let result = withUnsafeMutablePointer(to: &info) {
            proc_pid_rusage(pid, RUSAGE_INFO_V2,
                UnsafeMutableRawPointer($0).assumingMemoryBound(to: rusage_info_t?.self))
        }
        guard result == 0 else { return nil }
        return ProcessFootprint(bytes: info.ri_phys_footprint, startTime: info.ri_proc_start_abstime)
    }

    static func readProcesses() -> [ProcessMemorySnapshot] {
        let task = Process()
        let output = Pipe()
        task.executableURL = URL(fileURLWithPath: "/bin/ps")
        task.arguments = ["-A", "-c", "-o", "pid=,comm="]
        var environment = ProcessInfo.processInfo.environment
        environment["LC_ALL"] = "C"
        task.environment = environment
        task.standardOutput = output
        task.standardError = FileHandle.nullDevice
        do {
            try task.run()
            let data = output.fileHandleForReading.readDataToEndOfFile()
            task.waitUntilExit()
            guard task.terminationStatus == 0 else { return [] }
            return processSnapshots(String(decoding: data, as: UTF8.self))
        } catch {
            return []
        }
    }

    static func processSnapshots(_ output: String,
        footprintLookup: (pid_t) -> ProcessFootprint? = Self.readFootprint,
        identityLookup: (pid_t) -> ProcessIdentityResolution? = ProcessIdentityResolver.resolve
    ) -> [ProcessMemorySnapshot] {
        var seen = Set<pid_t>()
        let candidates = output.split(whereSeparator: \.isNewline).compactMap { line
            -> (pid: pid_t, name: String, footprint: ProcessFootprint)? in
            let fields = line.split(maxSplits: 1, whereSeparator: \.isWhitespace)
            guard fields.count == 2, let pid = pid_t(fields[0]), pid > 0,
                  seen.insert(pid).inserted,
                  let footprint = footprintLookup(pid), footprint.bytes > 0 else { return nil }
            return (pid, String(fields[1]), footprint)
        }.sorted {
            $0.footprint.bytes == $1.footprint.bytes ? $0.pid < $1.pid : $0.footprint.bytes > $1.footprint.bytes
        }
        // ponytail: top-five application totals are lower bounds, not complete app totals.
        // Expand candidate coverage only if real-world attribution misses justify the extra lookups.
        return candidates.prefix(5).compactMap { candidate in
            let identity = identityLookup(candidate.pid)
            guard let verified = footprintLookup(candidate.pid),
                  verified.startTime == candidate.footprint.startTime else { return nil }
            return ProcessMemorySnapshot(pid: candidate.pid,
                name: identity?.processDisplayName ?? candidate.name,
                physicalFootprint: candidate.footprint.bytes,
                applicationIdentity: identity?.applicationIdentity)
        }
    }
}
