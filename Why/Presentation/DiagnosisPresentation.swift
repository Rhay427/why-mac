struct DiagnosisPresentation: Equatable {
    struct SleepReminder: Equatable {
        let headline: String
        let detail: String
    }

    enum Kind: Equatable {
        case ready, checking, healthy, explanation, inconclusive
    }

    enum Tone: Equatable {
        case neutral, positive, warning, critical
    }

    let kind: Kind
    let tone: Tone
    let headline: String
    let detail: String
    let symbolName: String
    let sleepReminder: SleepReminder?

    init(
        diagnosis: Diagnosis,
        sleepReminder sleepReminderDiagnosis: Diagnosis? = nil,
        isChecking: Bool,
        hasCompletedCheck: Bool
    ) {
        if isChecking {
            self = Self(kind: .checking, tone: .neutral,
                headline: "Checking what your Mac is doing…",
                detail: "This takes about five seconds.", symbolName: "hourglass")
            return
        }

        guard hasCompletedCheck else {
            self = Self(kind: .ready, tone: .neutral,
                headline: "Understand what your Mac is doing",
                detail: "Why? checks your Mac only when you ask. It doesn’t monitor continuously, and each check takes about five seconds.",
                symbolName: "questionmark.circle")
            return
        }

        let sleepReminder = Self.sleepReminder(from: sleepReminderDiagnosis)

        switch diagnosis {
        case .inconclusive:
            self = Self(kind: .inconclusive, tone: .neutral,
                headline: "No clear explanation yet",
                detail: "Why? didn’t have enough reliable evidence in this check.",
                symbolName: "questionmark.circle", sleepReminder: sleepReminder)
        case .healthy:
            self = Self(kind: .healthy, tone: .positive,
                headline: "Nothing noteworthy found",
                detail: "Why? didn’t find anything that needs your attention in this check.",
                symbolName: "checkmark.circle.fill", sleepReminder: sleepReminder)
        case let .issue(severity, "Sleep blocker detected", explanation):
            self = Self(kind: .explanation,
                tone: severity == .critical ? .critical : .warning,
                headline: "Your Mac is being kept awake.", detail: explanation,
                symbolName: severity == .critical
                    ? "exclamationmark.octagon.fill"
                    : "exclamationmark.triangle.fill")
        case let .issue(severity, title, explanation):
            self = Self(kind: .explanation,
                tone: severity == .critical ? .critical : .warning,
                headline: Self.headline(for: title), detail: explanation,
                symbolName: severity == .critical
                    ? "exclamationmark.octagon.fill"
                    : "exclamationmark.triangle.fill",
                sleepReminder: sleepReminder)
        }
    }

    private init(
        kind: Kind,
        tone: Tone,
        headline: String,
        detail: String,
        symbolName: String,
        sleepReminder: SleepReminder? = nil
    ) {
        self.kind = kind
        self.tone = tone
        self.headline = headline
        self.detail = detail
        self.symbolName = symbolName
        self.sleepReminder = sleepReminder
    }

    private static func sleepReminder(from diagnosis: Diagnosis?) -> SleepReminder? {
        guard case let .issue(_, "Sleep blocker detected", explanation) = diagnosis else {
            return nil
        }
        return SleepReminder(headline: "Before you step away", detail: explanation)
    }

    private static func headline(for title: String) -> String {
        switch title {
        case "Battery use contributor": "A likely source of battery use"
        case "Sustained processor activity": "Your processor is staying busy"
        case "Memory pressure": "Your Mac is running low on memory"
        case "Critical memory pressure": "Your Mac is critically low on memory"
        default: title
        }
    }
}
