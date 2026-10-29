struct ValidDiagnoses: Equatable {
    let thermal: Diagnosis?
    let memory: Diagnosis?
    let battery: Diagnosis?
    let processor: Diagnosis?
    let sleep: Diagnosis?
    let fallback: Diagnosis

    init(
        thermal: Diagnosis? = nil,
        memory: Diagnosis? = nil,
        battery: Diagnosis? = nil,
        processor: Diagnosis? = nil,
        sleep: Diagnosis? = nil,
        fallback: Diagnosis
    ) {
        self.thermal = thermal
        self.memory = memory
        self.battery = battery
        self.processor = processor
        self.sleep = sleep
        self.fallback = fallback
    }
}

struct DiagnosisSelection: Equatable {
    enum Source: Equatable {
        case thermal, memory, battery, processor, sleep, fallback
    }

    let primary: Diagnosis
    let sleepReminder: Diagnosis?
    let source: Source
}

struct DiagnosisRelevance {
    func select(_ diagnoses: ValidDiagnoses, context: UserActivityContext) -> DiagnosisSelection {
        // Both contexts intentionally use the same V1 policy. The seam exists without inventing idle state.
        switch context {
        case .active, .unknown:
            break
        }

        if let primary = diagnoses.thermal {
            return DiagnosisSelection(primary: primary, sleepReminder: diagnoses.sleep, source: .thermal)
        }
        if let primary = diagnoses.memory {
            return DiagnosisSelection(primary: primary, sleepReminder: diagnoses.sleep, source: .memory)
        }
        if let primary = diagnoses.battery {
            return DiagnosisSelection(primary: primary, sleepReminder: diagnoses.sleep, source: .battery)
        }
        if let primary = diagnoses.processor {
            return DiagnosisSelection(primary: primary, sleepReminder: diagnoses.sleep, source: .processor)
        }
        if let sleep = diagnoses.sleep {
            return DiagnosisSelection(primary: sleep, sleepReminder: nil, source: .sleep)
        }
        return DiagnosisSelection(primary: diagnoses.fallback, sleepReminder: nil, source: .fallback)
    }
}
