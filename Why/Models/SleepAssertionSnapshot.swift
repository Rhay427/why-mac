import Darwin
import Foundation

struct SleepAssertionSnapshot {
    let pid: pid_t
    let assertionType: String
    let name: String?
    let humanReadableReason: String?
    let details: String?
    let level: UInt32
    let applicationIdentity: ApplicationIdentity?
    let processDisplayName: String

    var isActive: Bool {
        level == 255
    }
}
