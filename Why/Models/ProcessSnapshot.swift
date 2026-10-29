import Darwin
import Foundation

struct ApplicationIdentity: Equatable {
    struct GroupKey: Hashable {
        let bundleURL: URL
        let bundleIdentifier: String
    }

    let groupKey: GroupKey
    let displayName: String
}

struct ProcessSnapshot {
    let pid: pid_t
    let name: String
    let cpuUsage: Double
    let applicationIdentity: ApplicationIdentity?

    init(
        pid: pid_t,
        name: String,
        cpuUsage: Double,
        applicationIdentity: ApplicationIdentity? = nil
    ) {
        self.pid = pid
        self.name = name
        self.cpuUsage = cpuUsage
        self.applicationIdentity = applicationIdentity
    }
}
