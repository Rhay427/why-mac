import Foundation

enum MemoryPressureState {
    case unknown, normal, warning, critical

    var isElevated: Bool { self == .warning || self == .critical }
}

struct MemorySnapshot {
    let pressure: MemoryPressureState
    let physicalMemory: UInt64?
    let vm: MemoryVMStatistics?
    let processes: [ProcessMemorySnapshot]

    init(pressure: MemoryPressureState = .unknown, physicalMemory: UInt64? = nil,
         vm: MemoryVMStatistics? = nil, processes: [ProcessMemorySnapshot] = []) {
        self.pressure = pressure
        self.physicalMemory = physicalMemory
        self.vm = vm
        self.processes = processes
    }
}

struct ProcessMemorySnapshot {
    let pid: pid_t
    let name: String
    let physicalFootprint: UInt64
    let applicationIdentity: ApplicationIdentity?

    init(pid: pid_t, name: String, physicalFootprint: UInt64,
         applicationIdentity: ApplicationIdentity? = nil) {
        self.pid = pid
        self.name = name
        self.physicalFootprint = physicalFootprint
        self.applicationIdentity = applicationIdentity
    }
}

// Cumulative counters are context, never pressure signals or inferred rates.
struct MemoryVMStatistics {
    let pageSize: UInt64
    let freePages: UInt64
    let activePages: UInt64
    let inactivePages: UInt64
    let wiredPages: UInt64
    let compressorPages: UInt64
    let pageIns: UInt64
    let pageOuts: UInt64
    let compressions: UInt64
    let decompressions: UInt64
    let swapIns: UInt64
    let swapOuts: UInt64
    let swapUsedBytes: UInt64?
}
