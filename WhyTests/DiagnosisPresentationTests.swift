import XCTest
@testable import Why

final class DiagnosisPresentationTests: XCTestCase {
    func testHealthyUsesBoundedProductCopy() {
        let result = presentation(.healthy(title: "No supported sleep blocker detected", explanation: "Raw healthy detail"))

        XCTAssertEqual(result.kind, .healthy)
        XCTAssertEqual(result.headline, "Nothing noteworthy found")
        XCTAssertEqual(result.detail, "Why? didn’t find anything that needs your attention in this check.")
        XCTAssertEqual(result.tone, .positive)
    }

    func testThermalDiagnosisPreservesEngineExplanation() {
        let result = presentation(issue("Your Mac is running hot", "macOS reports serious thermal pressure."))

        XCTAssertEqual(result.kind, .explanation)
        XCTAssertEqual(result.headline, "Your Mac is running hot")
        XCTAssertEqual(result.detail, "macOS reports serious thermal pressure.")
    }

    func testSleepApplicationDiagnosisRemainsPlainLanguage() {
        let detail = "Slack is currently preventing your Mac from automatically going to sleep while idle."
        let result = presentation(issue("Sleep blocker detected", detail))

        XCTAssertEqual(result.headline, "Your Mac is being kept awake.")
        XCTAssertEqual(result.detail, detail)
    }

    func testSleepProcessDiagnosisRemainsPlainLanguage() {
        let detail = "caffeinate is currently preventing automatic idle sleep."
        XCTAssertEqual(presentation(issue("Sleep blocker detected", detail)).detail, detail)
    }

    func testSystemOnlySleepDiagnosisDoesNotInventAnApplication() {
        let detail = "A supported power assertion is currently preventing automatic idle sleep."
        XCTAssertEqual(presentation(issue("Sleep blocker detected", detail)).detail, detail)
    }

    func testMemoryApplicationDiagnosisPreservesCautiousAttribution() {
        let detail = "macOS is reporting elevated memory pressure. Google Chrome may be contributing."
        let result = presentation(issue("Memory pressure", detail))

        XCTAssertEqual(result.headline, "Your Mac is running low on memory")
        XCTAssertEqual(result.detail, detail)
    }

    func testMemorySystemOnlyDiagnosisDoesNotInventAContributor() {
        let detail = "macOS is reporting elevated memory pressure, which can make applications less responsive."
        XCTAssertEqual(presentation(issue("Memory pressure", detail)).detail, detail)
    }

    func testCriticalMemoryTitleRemainsCalmAndPlain() {
        XCTAssertEqual(
            presentation(issue("Critical memory pressure", "Reduce memory use.")).headline,
            "Your Mac is critically low on memory"
        )
    }

    func testBatteryContributorRemainsAnExplanation() {
        let result = presentation(issue("Battery use contributor", "Xcode is likely contributing to increased battery use."))
        XCTAssertEqual(result.kind, .explanation)
        XCTAssertEqual(result.tone, .warning)
        XCTAssertEqual(result.headline, "A likely source of battery use")
    }

    func testGenericSustainedCPUUsesExistingConclusion() {
        let detail = "Xcode is currently the main source of sustained processor activity."
        let result = presentation(issue("Sustained processor activity", detail))

        XCTAssertEqual(result.headline, "Your processor is staying busy")
        XCTAssertEqual(result.detail, detail)
    }

    func testCheckingOverridesThePreviousDiagnosis() {
        let result = DiagnosisPresentation(
            diagnosis: issue("Old result", "Old detail"),
            isChecking: true,
            hasCompletedCheck: true
        )

        XCTAssertEqual(result.kind, .checking)
        XCTAssertEqual(result.headline, "Checking what your Mac is doing…")
        XCTAssertEqual(result.detail, "This takes about five seconds.")
    }

    func testNegativeBatteryContributorResultIsPresentedAsHealthy() {
        let result = presentation(.healthy(
            title: "No processor-related battery contributor found",
            explanation: "No significant sustained processor activity was found. Other hardware and system activity may still be using battery power."
        ))

        XCTAssertEqual(result.kind, .healthy)
        XCTAssertEqual(result.headline, "Nothing noteworthy found")
        XCTAssertEqual(result.detail, "Why? didn’t find anything that needs your attention in this check.")
        XCTAssertEqual(result.tone, .positive)
    }

    func testGenuineInsufficientEvidenceIsPresentedAsInconclusive() {
        let result = presentation(.inconclusive)

        XCTAssertEqual(result.kind, .inconclusive)
        XCTAssertEqual(result.headline, "No clear explanation yet")
        XCTAssertEqual(result.detail, "Why? didn’t have enough reliable evidence in this check.")
        XCTAssertEqual(result.tone, .neutral)
    }

    func testLongApplicationNameIsNotTruncatedByPresentationLogic() {
        let name = "A Very Long Application Name Used for Important Work"
        let detail = "\(name) is currently keeping your display awake."
        XCTAssertEqual(presentation(issue("Sleep blocker detected", detail)).detail, detail)
    }

    func testInitialStateInvitesAnExplicitCheck() {
        let result = DiagnosisPresentation(
            diagnosis: .healthy(title: "Ignored", explanation: "Ignored"),
            isChecking: false,
            hasCompletedCheck: false
        )

        XCTAssertEqual(result.kind, .ready)
        XCTAssertEqual(result.headline, "Understand what your Mac is doing")
        XCTAssertEqual(
            result.detail,
            "Why? checks your Mac only when you ask. It doesn’t monitor continuously, and each check takes about five seconds."
        )
    }

    func testSleepReminderIsCompactAndPreservesDiagnosisContent() {
        let sleep = issue(
            "Sleep blocker detected",
            "Brave Browser is currently preventing your Mac from automatically going to sleep while idle."
        )
        let result = DiagnosisPresentation(
            diagnosis: issue("Sustained processor activity", "Xcode is active."),
            sleepReminder: sleep,
            isChecking: false,
            hasCompletedCheck: true
        )

        XCTAssertEqual(result.sleepReminder?.headline, "Before you step away")
        XCTAssertEqual(
            result.sleepReminder?.detail,
            "Brave Browser is currently preventing your Mac from automatically going to sleep while idle."
        )
    }

    private func presentation(_ diagnosis: Diagnosis) -> DiagnosisPresentation {
        DiagnosisPresentation(diagnosis: diagnosis, isChecking: false, hasCompletedCheck: true)
    }

    private func issue(_ title: String, _ explanation: String) -> Diagnosis {
        .issue(severity: .warning, title: title, explanation: explanation)
    }
}
