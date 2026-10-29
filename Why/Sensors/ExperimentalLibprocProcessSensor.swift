#if DEBUG
import Darwin
import Foundation

struct ExperimentalProcessCPUTimeSample {
    let pid: pid_t
    let name: String
    let cpuTimeNanoseconds: UInt64
}

// Development-only accuracy oracle. The Release build excludes this entire implementation.
struct ExperimentalLibprocProcessSensor {
    private static let timebase: (numerator: UInt32, denominator: UInt32) = {
        var info = mach_timebase_info_data_t()
        mach_timebase_info(&info)
        return (info.numer, info.denom)
    }()

    private var previous: (timestamp: Date, samples: [ExperimentalProcessCPUTimeSample])?

    mutating func read(at timestamp: Date = Date()) -> [ProcessSnapshot] {
        let current = Self.collect()
        defer { previous = (timestamp, current) }

        guard let previous else {
            return []
        }

        return Self.snapshots(
            previous: previous.samples,
            current: current,
            elapsedSeconds: timestamp.timeIntervalSince(previous.timestamp)
        )
    }

    static func snapshots(
        previous: [ExperimentalProcessCPUTimeSample],
        current: [ExperimentalProcessCPUTimeSample],
        elapsedSeconds: TimeInterval
    ) -> [ProcessSnapshot] {
        guard elapsedSeconds > 0 else {
            return []
        }

        let previousByPID = Dictionary(uniqueKeysWithValues: previous.map { ($0.pid, $0) })

        return current.compactMap { sample in
            guard
                let earlier = previousByPID[sample.pid],
                earlier.name == sample.name,
                sample.cpuTimeNanoseconds >= earlier.cpuTimeNanoseconds
            else {
                return nil
            }

            let delta = sample.cpuTimeNanoseconds - earlier.cpuTimeNanoseconds
            return ProcessSnapshot(
                pid: sample.pid,
                name: sample.name,
                cpuUsage: Double(delta) / 1_000_000_000 / elapsedSeconds * 100
            )
        }
        .sorted { $0.cpuUsage > $1.cpuUsage }
        .prefix(5)
        .map { $0 }
    }

    static func nanoseconds(
        fromMachTime value: UInt64,
        numerator: UInt32,
        denominator: UInt32
    ) -> UInt64 {
        guard denominator > 0 else {
            return 0
        }

        let numerator = UInt64(numerator)
        let denominator = UInt64(denominator)
        return value / denominator * numerator + value % denominator * numerator / denominator
    }

    private static func collect() -> [ExperimentalProcessCPUTimeSample] {
        let capacity = max(Int(proc_listallpids(nil, 0)), 1)
        var pids = [pid_t](repeating: 0, count: capacity)
        let count = pids.withUnsafeMutableBytes {
            proc_listallpids($0.baseAddress, Int32($0.count))
        }

        guard count > 0 else {
            return []
        }

        return pids.prefix(Int(count)).compactMap(sample)
    }

    private static func sample(pid: pid_t) -> ExperimentalProcessCPUTimeSample? {
        guard pid > 0 else {
            return nil
        }

        var taskInfo = proc_taskinfo()
        let taskInfoSize = Int32(MemoryLayout<proc_taskinfo>.size)
        let bytesRead = withUnsafeMutablePointer(to: &taskInfo) {
            proc_pidinfo(pid, PROC_PIDTASKINFO, 0, $0, taskInfoSize)
        }

        guard bytesRead == taskInfoSize else {
            return nil
        }

        var nameBuffer = [UInt8](repeating: 0, count: Int(MAXCOMLEN) * 2)
        let nameLength = nameBuffer.withUnsafeMutableBytes {
            proc_name(pid, $0.baseAddress, UInt32($0.count))
        }

        guard nameLength > 0 else {
            return nil
        }

        let cpuTime = taskInfo.pti_total_user + taskInfo.pti_total_system
        return ExperimentalProcessCPUTimeSample(
            pid: pid,
            name: String(decoding: nameBuffer.prefix(Int(nameLength)), as: UTF8.self),
            cpuTimeNanoseconds: nanoseconds(
                fromMachTime: cpuTime,
                numerator: timebase.numerator,
                denominator: timebase.denominator
            )
        )
    }
}
#endif
