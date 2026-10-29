enum DiagnosisSeverity: Equatable {
    case warning
    case critical
}

enum Diagnosis: Equatable {
    case healthy(title: String, explanation: String)
    case inconclusive
    case issue(severity: DiagnosisSeverity, title: String, explanation: String)
}
