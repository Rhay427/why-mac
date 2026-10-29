import Foundation

struct MemoryPressureRule {
    func evaluate(_ memory: MemorySnapshot) -> Diagnosis? {
        guard memory.pressure.isElevated else { return nil }
        let critical = memory.pressure == .critical
        var explanation = "macOS is reporting \(critical ? "critical" : "elevated") memory pressure, which can make applications less responsive."
        if let strongest = contributors(memory).first {
            explanation += " \(strongest.displayName) is currently one of the largest observable memory users and may be contributing."
        }
        return .issue(severity: critical ? .critical : .warning,
                      title: critical ? "Critical memory pressure" : "Memory pressure", explanation: explanation)
    }

    func contributors(_ memory: MemorySnapshot) -> [DiagnosisContributor] {
        var candidates: [DiagnosisContributor.ID: (name: String, bytes: UInt64,
            application: ApplicationIdentity?, pid: pid_t?)] = [:]
        for process in memory.processes where process.pid > 0 && process.physicalFootprint > 0 && !process.name.isEmpty {
            let key = process.applicationIdentity.map { DiagnosisContributor.ID.application($0.groupKey) }
                ?? .process(pid: process.pid, name: process.name)
            let name = process.applicationIdentity?.displayName ?? process.name
            let previous = candidates[key]
            let sum = (previous?.bytes ?? 0).addingReportingOverflow(process.physicalFootprint)
            candidates[key] = (
                min(previous?.name ?? name, name),
                sum.overflow ? UInt64.max : sum.partialValue,
                process.applicationIdentity,
                process.applicationIdentity == nil ? process.pid : nil
            )
        }
        return candidates.sorted {
            $0.value.bytes == $1.value.bytes
                ? $0.key.sortKey < $1.key.sortKey
                : $0.value.bytes > $1.value.bytes
        }
        .prefix(5)
        .map { key, value in
            DiagnosisContributor(id: key, displayName: value.name,
                applicationIdentity: value.application, processIdentifier: value.pid,
                metric: .memoryFootprint(value.bytes))
        }
    }
}
