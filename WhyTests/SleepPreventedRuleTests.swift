import XCTest
@testable import Why

final class SleepPreventedRuleTests: XCTestCase {
    func testApplicationIdleSleepAssertionProducesApplicationDiagnosis() {
        let assertion = sleepAssertion(
            type: "PreventUserIdleSystemSleep",
            application: application("Example App", id: "com.example.app")
        )

        XCTAssertEqual(
            SleepPreventedRule().evaluate(snapshot(assertions: [assertion])),
            .issue(
                severity: .warning,
                title: "Sleep blocker detected",
                explanation: "Example App is currently preventing your Mac from automatically going to sleep while idle."
            )
        )
    }

    func testRealNoIdleSleepAssertionUsesApplicationIdentity() {
        let assertion = sleepAssertion(
            type: "NoIdleSleepAssertion",
            application: application("Brave Browser", id: "com.brave.Browser")
        )

        XCTAssertEqual(
            explanation(for: [assertion]),
            "Brave Browser is currently preventing your Mac from automatically going to sleep while idle."
        )
    }

    func testCLIAssertionProducesProcessFallbackDiagnosis() {
        let assertion = sleepAssertion(type: "PreventUserIdleSystemSleep", processName: "caffeinate")

        XCTAssertEqual(
            explanation(for: [assertion]),
            "caffeinate is currently preventing automatic idle sleep."
        )
    }

    func testDisplayOnlyAssertionUsesDisplaySpecificDiagnosis() {
        let assertion = sleepAssertion(
            type: "PreventUserIdleDisplaySleep",
            application: application("Presentation", id: "com.example.presentation")
        )

        XCTAssertEqual(explanation(for: [assertion]), "Presentation is currently keeping your display awake.")
    }

    func testRealNoDisplaySleepAssertionUsesDisplaySpecificDiagnosis() {
        let assertion = sleepAssertion(
            type: "NoDisplaySleepAssertion",
            application: application("Brave Browser", id: "com.brave.Browser")
        )

        XCTAssertEqual(explanation(for: [assertion]), "Brave Browser is currently keeping your display awake.")
    }

    func testSystemSleepAssertionUsesRequestWording() {
        let assertion = sleepAssertion(
            type: "PreventSystemSleep",
            application: application("Backup", id: "com.example.backup")
        )

        XCTAssertEqual(explanation(for: [assertion]), "Backup is currently requesting that your Mac remain awake.")
    }

    func testNormalPowerdAssertionIsIgnored() {
        let assertion = sleepAssertion(type: "PreventUserIdleSystemSleep", processName: "powerd")

        XCTAssertHealthy(SleepPreventedRule().evaluate(snapshot(assertions: [assertion])))
    }

    func testNonActionableSystemDaemonAssertionsAreIgnored() {
        for process in ["coreaudiod", "runningboardd"] {
            let assertion = sleepAssertion(type: "PreventUserIdleSystemSleep", processName: process)
            XCTAssertHealthy(SleepPreventedRule().evaluate(snapshot(assertions: [assertion])))
        }
    }

    func testSystemLibraryApplicationIsIgnoredAsNormalInfrastructure() {
        let assertion = sleepAssertion(
            type: "PreventUserIdleSystemSleep",
            application: application(
                "AddressBookSourceSync",
                id: "com.apple.AddressBook.SourceSync",
                bundleURL: URL(
                    fileURLWithPath: "/System/Library/Frameworks/AddressBook.framework/Versions/A/Resources/AddressBookSourceSync.app"
                )
            )
        )

        XCTAssertHealthy(SleepPreventedRule().evaluate(snapshot(assertions: [assertion])))
    }

    func testUserIsActiveAssertionIsIgnored() {
        let assertion = sleepAssertion(type: "UserIsActive", processName: "WindowServer")

        XCTAssertHealthy(SleepPreventedRule().evaluate(snapshot(assertions: [assertion])))
    }

    func testMultipleAssertionsFromOneApplicationConsolidateToHighestPriorityMeaning() {
        let app = application("Video Player", id: "com.example.video")
        let assertions = [
            sleepAssertion(type: "PreventSystemSleep", application: app),
            sleepAssertion(type: "PreventUserIdleDisplaySleep", application: app),
            sleepAssertion(type: "PreventUserIdleSystemSleep", application: app)
        ]

        XCTAssertEqual(
            explanation(for: assertions),
            "Video Player is currently preventing your Mac from automatically going to sleep while idle."
        )
    }

    func testApplicationPriorityBeatsIndependentProcessOwnerDeterministically() {
        let assertions = [
            sleepAssertion(type: "PreventUserIdleSystemSleep", pid: 10, processName: "caffeinate"),
            sleepAssertion(
                type: "PreventSystemSleep",
                pid: 20,
                application: application("Backup", id: "com.example.backup")
            )
        ]

        XCTAssertEqual(explanation(for: assertions), "Backup is currently requesting that your Mac remain awake.")
    }

    func testAssertionWithoutReasonRemainsDiagnosable() {
        let assertion = sleepAssertion(
            type: "PreventUserIdleDisplaySleep",
            reason: nil,
            details: nil,
            processName: "display-tool"
        )

        XCTAssertEqual(explanation(for: [assertion]), "display-tool is currently keeping your display awake.")
    }

    func testUnknownAssertionIsIgnored() {
        let assertion = sleepAssertion(type: "InternalFutureAssertion", processName: "helper")

        XCTAssertHealthy(SleepPreventedRule().evaluate(snapshot(assertions: [assertion])))
    }

    func testNetworkActivityUsesCautiousLanguage() {
        let assertion = sleepAssertion(type: "NetworkClientActive", processName: "sync-helper")

        XCTAssertEqual(
            explanation(for: [assertion]),
            "sync-helper is reporting network activity that may delay automatic sleep."
        )
    }

    func testNoSupportedBlockerUsesBoundedHealthyLanguage() {
        XCTAssertEqual(
            SleepPreventedRule().evaluate(snapshot(assertions: [])),
            .healthy(
                title: "No supported sleep blocker detected",
                explanation: "No supported application sleep blocker is currently active."
            )
        )
    }

    func testFailedApplicationAttributionFallsBackToProcess() {
        let assertion = sleepAssertion(type: "PreventSystemSleep", processName: "backup-helper")

        XCTAssertEqual(
            explanation(for: [assertion]),
            "backup-helper is currently requesting that your Mac remain awake."
        )
    }

    private func sleepAssertion(
        type: String,
        pid: pid_t = 100,
        reason: String? = "Working",
        details: String? = "Working",
        processName: String = "helper",
        application: ApplicationIdentity? = nil
    ) -> SleepAssertionSnapshot {
        SleepAssertionSnapshot(
            pid: pid,
            assertionType: type,
            name: "Test assertion",
            humanReadableReason: reason,
            details: details,
            level: 255,
            applicationIdentity: application,
            processDisplayName: processName
        )
    }

    private func application(
        _ name: String,
        id: String,
        bundleURL: URL? = nil
    ) -> ApplicationIdentity {
        ApplicationIdentity(
            groupKey: ApplicationIdentity.GroupKey(
                bundleURL: bundleURL ?? URL(fileURLWithPath: "/Applications/\(name).app"),
                bundleIdentifier: id
            ),
            displayName: name
        )
    }

    private func snapshot(assertions: [SleepAssertionSnapshot]) -> SystemSnapshot {
        SystemSnapshot(
            timestamp: Date(timeIntervalSince1970: 0),
            thermalState: .nominal,
            power: PowerSnapshot(batteryPercentage: nil, isCharging: nil, source: .unknown),
            processes: [],
            sleepAssertions: assertions
        )
    }

    private func explanation(for assertions: [SleepAssertionSnapshot]) -> String? {
        guard case let .issue(_, _, explanation) = SleepPreventedRule().evaluate(snapshot(assertions: assertions)) else {
            return nil
        }
        return explanation
    }

    private func XCTAssertHealthy(_ diagnosis: Diagnosis, file: StaticString = #filePath, line: UInt = #line) {
        guard case .healthy = diagnosis else {
            return XCTFail("Expected a bounded healthy result", file: file, line: line)
        }
    }
}
