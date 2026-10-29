import Darwin
import Foundation

enum ContributorMetric: Equatable {
    case cpuPercentage(Double)
    case memoryFootprint(UInt64)

    var displayValue: String {
        switch self {
        case let .cpuPercentage(value):
            let precision = value.rounded() == value ? 0 : 1
            return value.formatted(.number.precision(.fractionLength(precision))) + "% CPU"
        case let .memoryFootprint(bytes):
            return ByteCountFormatter.string(fromByteCount: Int64(clamping: bytes), countStyle: .memory)
                + " memory"
        }
    }
}

struct DiagnosisContributor: Identifiable, Equatable {
    enum ID: Hashable {
        case application(ApplicationIdentity.GroupKey)
        case process(pid: pid_t, name: String)

        var sortKey: String {
            switch self {
            case let .application(groupKey):
                "0|\(groupKey.bundleIdentifier)|\(groupKey.bundleURL.path)"
            case let .process(pid, name):
                "1|\(String(format: "%010d", pid))|\(name)"
            }
        }
    }

    let id: ID
    let displayName: String
    let applicationIdentity: ApplicationIdentity?
    let processIdentifier: pid_t?
    let metric: ContributorMetric
}

struct DiagnosisContributors: Equatable {
    let title: String
    let items: [DiagnosisContributor]

    static func make(
        selection: DiagnosisSelection,
        first: SystemSnapshot,
        second: SystemSnapshot
    ) -> DiagnosisContributors? {
        make(source: selection.source, first: first, second: second)
    }

    static func make(
        source: DiagnosisSelection.Source,
        first: SystemSnapshot,
        second: SystemSnapshot
    ) -> DiagnosisContributors? {
        let title: String
        let items: [DiagnosisContributor]
        switch source {
        case .processor:
            title = "Top contributors"
            items = HighCPUProcessRule().contributors(first, second)
        case .battery:
            title = "Top processor contributors"
            items = HighCPUProcessRule().contributors(first, second)
        case .memory:
            title = "Top contributors"
            items = MemoryPressureRule().contributors(second.memory)
        case .thermal, .sleep, .fallback:
            return nil
        }

        return items.isEmpty ? nil : DiagnosisContributors(title: title, items: items)
    }
}
