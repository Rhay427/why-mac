import XCTest
@testable import Why

final class HighCPUProcessRuleTests: XCTestCase {
    func testSustainedHighProcessProducesDiagnosis() {
        let first = snapshot(processes: [
            ProcessSnapshot(pid: 100, name: "Xcode", cpuUsage: 82)
        ])
        let second = snapshot(processes: [
            ProcessSnapshot(pid: 100, name: "Xcode", cpuUsage: 76)
        ])

        guard case let .issue(severity, _, explanation) = HighCPUProcessRule().evaluate(first, second) else {
            return XCTFail("A sustained high process should produce a diagnosis")
        }

        XCTAssertEqual(severity, .warning)
        XCTAssertEqual(explanation, "Xcode is currently the main source of sustained processor activity.")
        XCTAssertFalse(explanation.contains("%"))
    }

    func testOneSnapshotSpikeProducesNoDiagnosis() {
        let first = snapshot(processes: [
            ProcessSnapshot(pid: 100, name: "Xcode", cpuUsage: 82)
        ])
        let second = snapshot(processes: [
            ProcessSnapshot(pid: 100, name: "Xcode", cpuUsage: 12)
        ])

        XCTAssertNil(HighCPUProcessRule().evaluate(first, second))
    }

    func testBelowThresholdSustainedProcessProducesNoDiagnosis() {
        let first = snapshot(processes: [
            ProcessSnapshot(pid: 100, name: "Xcode", cpuUsage: 49.9)
        ])
        let second = snapshot(processes: [
            ProcessSnapshot(pid: 100, name: "Xcode", cpuUsage: 49.9)
        ])

        XCTAssertNil(HighCPUProcessRule().evaluate(first, second))
    }

    func testDifferentPIDOrNameDoesNotMatchAcrossSnapshots() {
        let first = snapshot(processes: [
            ProcessSnapshot(pid: 100, name: "Xcode", cpuUsage: 90),
            ProcessSnapshot(pid: 200, name: "clang", cpuUsage: 80)
        ])
        let second = snapshot(processes: [
            ProcessSnapshot(pid: 101, name: "Xcode", cpuUsage: 90),
            ProcessSnapshot(pid: 200, name: "swiftc", cpuUsage: 80)
        ])

        XCTAssertNil(HighCPUProcessRule().evaluate(first, second))
    }

    func testStrongestSustainedCandidateWins() {
        let first = snapshot(processes: [
            ProcessSnapshot(pid: 100, name: "Xcode", cpuUsage: 90),
            ProcessSnapshot(pid: 200, name: "clang", cpuUsage: 70),
            ProcessSnapshot(pid: 300, name: "swift-frontend", cpuUsage: 95)
        ])
        let second = snapshot(processes: [
            ProcessSnapshot(pid: 100, name: "Xcode", cpuUsage: 60),
            ProcessSnapshot(pid: 200, name: "clang", cpuUsage: 70),
            ProcessSnapshot(pid: 300, name: "swift-frontend", cpuUsage: 70)
        ])

        guard case let .issue(_, _, explanation) = HighCPUProcessRule().evaluate(first, second) else {
            return XCTFail("The strongest sustained process should produce a diagnosis")
        }

        XCTAssertEqual(
            explanation,
            "swift-frontend is currently the main source of sustained processor activity."
        )
    }

    func testProcessesFromOneApplicationCombineCPU() {
        let xcode = application(path: "/Applications/Xcode.app", id: "com.apple.dt.Xcode", name: "Xcode")
        let first = snapshot(processes: [
            ProcessSnapshot(pid: 100, name: "xcodebuild", cpuUsage: 30, applicationIdentity: xcode),
            ProcessSnapshot(pid: 101, name: "swift-frontend", cpuUsage: 25, applicationIdentity: xcode)
        ])
        let second = snapshot(processes: [
            ProcessSnapshot(pid: 100, name: "xcodebuild", cpuUsage: 28, applicationIdentity: xcode),
            ProcessSnapshot(pid: 101, name: "swift-frontend", cpuUsage: 24, applicationIdentity: xcode)
        ])

        XCTAssertEqual(explanation(for: first, second), "Xcode is currently the main source of sustained processor activity.")
    }

    func testApplicationIdentitySurvivesProcessHandoff() {
        let xcode = application(path: "/Applications/Xcode.app", id: "com.apple.dt.Xcode", name: "Xcode")
        let first = snapshot(processes: [
            ProcessSnapshot(pid: 100, name: "xcodebuild", cpuUsage: 70, applicationIdentity: xcode)
        ])
        let second = snapshot(processes: [
            ProcessSnapshot(pid: 200, name: "swift-frontend", cpuUsage: 65, applicationIdentity: xcode)
        ])

        XCTAssertEqual(explanation(for: first, second), "Xcode is currently the main source of sustained processor activity.")
    }

    func testUnrelatedStandaloneProcessesRemainSeparate() {
        let first = snapshot(processes: [
            ProcessSnapshot(pid: 100, name: "yes", cpuUsage: 30),
            ProcessSnapshot(pid: 200, name: "openssl", cpuUsage: 30)
        ])
        let second = snapshot(processes: [
            ProcessSnapshot(pid: 100, name: "yes", cpuUsage: 30),
            ProcessSnapshot(pid: 200, name: "openssl", cpuUsage: 30)
        ])

        XCTAssertNil(HighCPUProcessRule().evaluate(first, second))
    }

    func testSimilarProcessNamesDoNotGroup() {
        let first = snapshot(processes: [
            ProcessSnapshot(pid: 100, name: "PhotoWorker", cpuUsage: 30),
            ProcessSnapshot(pid: 200, name: "PhotoWorkerHelper", cpuUsage: 30)
        ])
        let second = snapshot(processes: [
            ProcessSnapshot(pid: 100, name: "PhotoWorker", cpuUsage: 30),
            ProcessSnapshot(pid: 200, name: "PhotoWorkerHelper", cpuUsage: 30)
        ])

        XCTAssertNil(HighCPUProcessRule().evaluate(first, second))
    }

    func testUnresolvedApplicationIdentityFallsBackToProcessIdentity() {
        let first = snapshot(processes: [
            ProcessSnapshot(pid: 100, name: "yes", cpuUsage: 70)
        ])
        let second = snapshot(processes: [
            ProcessSnapshot(pid: 100, name: "yes", cpuUsage: 65)
        ])

        XCTAssertEqual(explanation(for: first, second), "yes is currently the main source of sustained processor activity.")
    }

    func testStrongerGroupedApplicationBeatsIndividualProcess() {
        let chrome = application(path: "/Applications/Google Chrome.app", id: "com.google.Chrome", name: "Google Chrome")
        let first = snapshot(processes: [
            ProcessSnapshot(pid: 100, name: "Chrome", cpuUsage: 45, applicationIdentity: chrome),
            ProcessSnapshot(pid: 101, name: "Chrome Helper", cpuUsage: 35, applicationIdentity: chrome),
            ProcessSnapshot(pid: 200, name: "yes", cpuUsage: 70)
        ])
        let second = snapshot(processes: [
            ProcessSnapshot(pid: 100, name: "Chrome", cpuUsage: 40, applicationIdentity: chrome),
            ProcessSnapshot(pid: 101, name: "Chrome Helper", cpuUsage: 35, applicationIdentity: chrome),
            ProcessSnapshot(pid: 200, name: "yes", cpuUsage: 70)
        ])

        XCTAssertEqual(explanation(for: first, second), "Google Chrome is currently the main source of sustained processor activity.")
    }

    func testStrongerIndividualProcessBeatsGroupedApplication() {
        let chrome = application(path: "/Applications/Google Chrome.app", id: "com.google.Chrome", name: "Google Chrome")
        let first = snapshot(processes: [
            ProcessSnapshot(pid: 100, name: "Chrome", cpuUsage: 30, applicationIdentity: chrome),
            ProcessSnapshot(pid: 101, name: "Chrome Helper", cpuUsage: 30, applicationIdentity: chrome),
            ProcessSnapshot(pid: 200, name: "yes", cpuUsage: 80)
        ])
        let second = snapshot(processes: [
            ProcessSnapshot(pid: 100, name: "Chrome", cpuUsage: 30, applicationIdentity: chrome),
            ProcessSnapshot(pid: 101, name: "Chrome Helper", cpuUsage: 30, applicationIdentity: chrome),
            ProcessSnapshot(pid: 200, name: "yes", cpuUsage: 75)
        ])

        XCTAssertEqual(explanation(for: first, second), "yes is currently the main source of sustained processor activity.")
    }

    private func application(path: String, id: String, name: String) -> ApplicationIdentity {
        ApplicationIdentity(
            groupKey: ApplicationIdentity.GroupKey(
                bundleURL: URL(fileURLWithPath: path),
                bundleIdentifier: id
            ),
            displayName: name
        )
    }

    private func explanation(for first: SystemSnapshot, _ second: SystemSnapshot) -> String? {
        guard case let .issue(_, _, explanation) = HighCPUProcessRule().evaluate(first, second) else {
            return nil
        }
        return explanation
    }

    private func snapshot(processes: [ProcessSnapshot]) -> SystemSnapshot {
        SystemSnapshot(
            timestamp: Date(timeIntervalSince1970: 0),
            thermalState: .nominal,
            power: PowerSnapshot(batteryPercentage: nil, isCharging: nil, source: .unknown),
            processes: processes
        )
    }
}
