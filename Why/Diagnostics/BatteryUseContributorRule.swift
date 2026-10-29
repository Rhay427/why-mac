import Foundation

struct BatteryUseContributorRule {
    private static let maximumObservationInterval: TimeInterval = 10

    func evaluate(_ first: SystemSnapshot, _ second: SystemSnapshot) -> Diagnosis? {
        guard Self.isValidObservation(first, second) else {
            return nil
        }

        guard let contributor = HighCPUProcessRule().strongestContributor(first, second) else {
            return .healthy(
                title: "No processor-related battery contributor found",
                explanation: "No significant sustained processor activity was found. Other hardware and system activity may still be using battery power."
            )
        }

        var explanation = "\(contributor.displayName) is using sustained processor resources while your Mac is on battery and is likely contributing to increased battery use."
        if second.thermalState == .fair || second.thermalState == .serious || second.thermalState == .critical {
            explanation += " macOS is also reporting elevated thermal pressure."
        }

        return .issue(
            severity: .warning,
            title: "Battery use contributor",
            explanation: explanation
        )
    }

    private static func isValidObservation(_ first: SystemSnapshot, _ second: SystemSnapshot) -> Bool {
        let interval = second.timestamp.timeIntervalSince(first.timestamp)
        guard interval >= 0, interval <= maximumObservationInterval else {
            // A long gap may indicate sleep/wake; it is only an invalidation signal, not proof.
            return false
        }

        return first.power.source == .battery
            && second.power.source == .battery
            && first.power.isBatteryProvidingPower == true
            && second.power.isBatteryProvidingPower == true
            && first.power.isExternalPowerAvailable != true
            && second.power.isExternalPowerAvailable != true
            && first.power.isCharging == false
            && second.power.isCharging == false
    }
}
