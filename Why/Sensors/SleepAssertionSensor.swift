import Foundation
import IOKit.pwr_mgt

struct SleepAssertionSensor {
    func read() -> (assertions: [SleepAssertionSnapshot], succeeded: Bool) {
        var assertions: Unmanaged<CFDictionary>?
        guard
            IOPMCopyAssertionsByProcess(&assertions) == kIOReturnSuccess,
            let assertions
        else {
            return ([], false)
        }

        return (Self.parse(assertions.takeRetainedValue() as NSDictionary), true)
    }

    static func parse(
        _ assertionsByPID: NSDictionary,
        identityLookup: (pid_t) -> ProcessIdentityResolution? = ProcessIdentityResolver.resolve
    ) -> [SleepAssertionSnapshot] {
        var snapshots: [SleepAssertionSnapshot] = []

        for (rawPID, rawAssertions) in assertionsByPID {
            guard
                let pidNumber = rawPID as? NSNumber,
                pidNumber.int64Value > 0,
                pidNumber.int64Value <= Int64(pid_t.max),
                let assertions = rawAssertions as? NSArray
            else {
                continue
            }

            let pid = pid_t(pidNumber.int32Value)
            let identity = identityLookup(pid)

            for case let properties as NSDictionary in assertions {
                guard
                    let assertionType = normalizedString(properties[kIOPMAssertionTypeKey]),
                    let levelNumber = properties[kIOPMAssertionLevelKey] as? NSNumber,
                    levelNumber.int64Value >= 0,
                    levelNumber.int64Value <= Int64(UInt32.max)
                else {
                    continue
                }

                let level = levelNumber.uint32Value
                guard level == UInt32(kIOPMAssertionLevelOn) else {
                    continue
                }

                snapshots.append(
                    SleepAssertionSnapshot(
                        pid: pid,
                        assertionType: assertionType,
                        name: normalizedString(properties[kIOPMAssertionNameKey]),
                        humanReadableReason: normalizedString(properties[kIOPMAssertionHumanReadableReasonKey]),
                        details: normalizedString(properties[kIOPMAssertionDetailsKey]),
                        level: level,
                        applicationIdentity: identity?.applicationIdentity,
                        processDisplayName: identity?.processDisplayName ?? "Process \(pid)"
                    )
                )
            }
        }

        return snapshots.sorted {
            ($0.pid, $0.assertionType, $0.name ?? "") < ($1.pid, $1.assertionType, $1.name ?? "")
        }
    }

    private static func normalizedString(_ value: Any?) -> String? {
        guard let value = value as? String else {
            return nil
        }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
