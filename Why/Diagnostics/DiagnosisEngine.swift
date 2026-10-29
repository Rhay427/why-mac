import Foundation

struct DiagnosisEngine {
    func evaluate(_ first: SystemSnapshot, _ second: SystemSnapshot) -> Diagnosis {
        let currentDiagnosis = evaluate(second)
        if case .issue = currentDiagnosis {
            return currentDiagnosis
        }
        let processCollectionSucceeded = first.processCollectionSucceeded
            && second.processCollectionSucceeded
        let batteryDiagnosis = processCollectionSucceeded
            ? BatteryUseContributorRule().evaluate(first, second)
            : nil
        if let batteryDiagnosis, case .issue = batteryDiagnosis {
            return batteryDiagnosis
        }
        if processCollectionSucceeded,
           let processorDiagnosis = HighCPUProcessRule().evaluate(first, second) {
            return processorDiagnosis
        }
        if !processCollectionSucceeded || currentDiagnosis == .inconclusive {
            return .inconclusive
        }
        return batteryDiagnosis ?? currentDiagnosis
    }

    func evaluate(_ snapshot: SystemSnapshot) -> Diagnosis {
        if let thermalDiagnosis = thermalDiagnosis(snapshot) {
            return thermalDiagnosis
        }
        let sleepDiagnosis = snapshot.sleepAssertionCollectionSucceeded
            ? SleepPreventedRule().evaluate(snapshot)
            : .inconclusive
        if case .issue = sleepDiagnosis { return sleepDiagnosis }
        if let memoryDiagnosis = MemoryPressureRule().evaluate(snapshot.memory) {
            return memoryDiagnosis
        }
        guard snapshot.processCollectionSucceeded else { return .inconclusive }
        return sleepDiagnosis
    }

    func validDiagnoses(_ first: SystemSnapshot, _ second: SystemSnapshot) -> ValidDiagnoses {
        let processCollectionSucceeded = first.processCollectionSucceeded
            && second.processCollectionSucceeded
        let sleepResult = second.sleepAssertionCollectionSucceeded
            ? SleepPreventedRule().evaluate(second)
            : .inconclusive
        let batteryResult = processCollectionSucceeded
            ? BatteryUseContributorRule().evaluate(first, second)
            : nil
        let collectionsSucceeded = processCollectionSucceeded
            && second.sleepAssertionCollectionSucceeded

        return ValidDiagnoses(
            thermal: thermalDiagnosis(second),
            memory: MemoryPressureRule().evaluate(second.memory),
            battery: issueOnly(batteryResult),
            processor: processCollectionSucceeded
                ? HighCPUProcessRule().evaluate(first, second)
                : nil,
            sleep: issueOnly(sleepResult),
            fallback: collectionsSucceeded
                ? healthyOnly(batteryResult) ?? evaluate(second)
                : .inconclusive
        )
    }

    private func thermalDiagnosis(_ snapshot: SystemSnapshot) -> Diagnosis? {
        switch snapshot.thermalState {
        case .serious:
            return .issue(
                severity: .warning,
                title: "Your Mac is running hot",
                explanation: "macOS reports serious thermal pressure and may temporarily reduce performance."
            )
        case .critical:
            return .issue(
                severity: .critical,
                title: "Your Mac is under critical thermal pressure",
                explanation: "Reduce demanding activity and allow your Mac to cool."
            )
        case .nominal, .fair:
            return nil
        @unknown default:
            return nil
        }
    }

    private func issueOnly(_ diagnosis: Diagnosis?) -> Diagnosis? {
        guard let diagnosis, case .issue = diagnosis else { return nil }
        return diagnosis
    }

    private func healthyOnly(_ diagnosis: Diagnosis?) -> Diagnosis? {
        guard let diagnosis, case .healthy = diagnosis else { return nil }
        return diagnosis
    }
}
