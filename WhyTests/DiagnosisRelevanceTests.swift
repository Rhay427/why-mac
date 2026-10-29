import XCTest
@testable import Why

final class DiagnosisRelevanceTests: XCTestCase {
    private let healthy = Diagnosis.healthy(
        title: "No supported sleep blocker detected",
        explanation: "No supported application sleep blocker is currently active."
    )
    private let sleep = Diagnosis.issue(
        severity: .warning,
        title: "Sleep blocker detected",
        explanation: "Brave Browser is currently preventing your Mac from automatically going to sleep while idle."
    )

    func testCPUIsPrimaryAndSleepBecomesReminder() {
        let cpu = issue("Sustained processor activity", "Xcode is currently the main source of sustained processor activity.")

        let result = select(processor: cpu, sleep: sleep, context: .active)

        XCTAssertEqual(result.primary, cpu)
        XCTAssertEqual(result.sleepReminder, sleep)
    }

    func testBatteryContributorIsPrimaryAndSleepBecomesReminder() {
        let battery = issue("Battery use contributor", "Xcode is likely contributing to increased battery use.")

        let result = select(battery: battery, sleep: sleep, context: .active)

        XCTAssertEqual(result.primary, battery)
        XCTAssertEqual(result.sleepReminder, sleep)
    }

    func testMemoryPressureIsPrimaryAndSleepBecomesReminder() {
        let memory = issue("Memory pressure", "macOS is reporting elevated memory pressure.")

        let result = select(memory: memory, sleep: sleep, context: .unknown)

        XCTAssertEqual(result.primary, memory)
        XCTAssertEqual(result.sleepReminder, sleep)
    }

    func testThermalPressureIsPrimaryAndSleepBecomesReminder() {
        let thermal = issue("Your Mac is running hot", "macOS reports serious thermal pressure.")

        let result = select(thermal: thermal, sleep: sleep, context: .active)

        XCTAssertEqual(result.primary, thermal)
        XCTAssertEqual(result.sleepReminder, sleep)
    }

    func testSleepOnlyBecomesPrimaryWithoutFalseHealthyState() {
        let result = select(sleep: sleep, context: .active)

        XCTAssertEqual(result.primary, sleep)
        XCTAssertNil(result.sleepReminder)
    }

    func testNoActionableDiagnosisPreservesHealthyAndInconclusiveFallbackSemantics() {
        XCTAssertEqual(select(context: .unknown).primary, healthy)
        XCTAssertEqual(select(fallback: .inconclusive, context: .unknown).primary, .inconclusive)
    }

    func testSleepDiagnosisContentsAreUnchangedInEitherPresentationRole() {
        let cpu = issue("Sustained processor activity", "Xcode is active.")

        XCTAssertEqual(select(sleep: sleep, context: .unknown).primary, sleep)
        XCTAssertEqual(select(processor: cpu, sleep: sleep, context: .unknown).sleepReminder, sleep)
    }

    func testActivityContextDoesNotChangeDiagnosticTruth() {
        let cpu = issue("Sustained processor activity", "Xcode is active.")
        let diagnoses = ValidDiagnoses(processor: cpu, sleep: sleep, fallback: healthy)

        XCTAssertEqual(
            DiagnosisRelevance().select(diagnoses, context: .active),
            DiagnosisRelevance().select(diagnoses, context: .unknown)
        )
    }

    func testPrimaryPriorityIsThermalThenMemoryThenBatteryThenProcessor() {
        let thermal = issue("Thermal", "thermal")
        let memory = issue("Memory", "memory")
        let battery = issue("Battery", "battery")
        let processor = issue("Processor", "processor")
        let relevance = DiagnosisRelevance()

        XCTAssertEqual(relevance.select(
            ValidDiagnoses(thermal: thermal, memory: memory, battery: battery,
                processor: processor, fallback: healthy), context: .unknown
        ).primary, thermal)
        XCTAssertEqual(relevance.select(
            ValidDiagnoses(memory: memory, battery: battery, processor: processor,
                fallback: healthy), context: .unknown
        ).primary, memory)
        XCTAssertEqual(relevance.select(
            ValidDiagnoses(battery: battery, processor: processor, fallback: healthy),
            context: .unknown
        ).primary, battery)
        XCTAssertEqual(relevance.select(
            ValidDiagnoses(processor: processor, fallback: healthy), context: .unknown
        ).primary, processor)
    }

    func testEngineKeepsCPUAndSleepAsSimultaneouslyValidDiagnoses() {
        let first = snapshot(
            timestamp: 0,
            processes: [ProcessSnapshot(pid: 100, name: "Xcode", cpuUsage: 80)],
            sleepAssertions: [sleepAssertion]
        )
        let second = snapshot(
            timestamp: 5,
            processes: [ProcessSnapshot(pid: 100, name: "Xcode", cpuUsage: 75)],
            sleepAssertions: [sleepAssertion]
        )

        let diagnoses = DiagnosisEngine().validDiagnoses(first, second)

        XCTAssertEqual(diagnoses.processor, issue(
            "Sustained processor activity",
            "Xcode is currently the main source of sustained processor activity."
        ))
        XCTAssertEqual(diagnoses.sleep, Diagnosis.issue(
            severity: .warning,
            title: "Sleep blocker detected",
            explanation: "caffeinate is currently preventing automatic idle sleep."
        ))
    }

    private func select(
        thermal: Diagnosis? = nil,
        memory: Diagnosis? = nil,
        battery: Diagnosis? = nil,
        processor: Diagnosis? = nil,
        sleep: Diagnosis? = nil,
        fallback: Diagnosis? = nil,
        context: UserActivityContext
    ) -> DiagnosisSelection {
        DiagnosisRelevance().select(
            ValidDiagnoses(
                thermal: thermal,
                memory: memory,
                battery: battery,
                processor: processor,
                sleep: sleep,
                fallback: fallback ?? healthy
            ),
            context: context
        )
    }

    private func issue(_ title: String, _ explanation: String) -> Diagnosis {
        .issue(severity: .warning, title: title, explanation: explanation)
    }

    private var sleepAssertion: SleepAssertionSnapshot {
        SleepAssertionSnapshot(
            pid: 200,
            assertionType: "PreventUserIdleSystemSleep",
            name: nil,
            humanReadableReason: nil,
            details: nil,
            level: 255,
            applicationIdentity: nil,
            processDisplayName: "caffeinate"
        )
    }

    private func snapshot(
        timestamp: TimeInterval,
        processes: [ProcessSnapshot],
        sleepAssertions: [SleepAssertionSnapshot]
    ) -> SystemSnapshot {
        SystemSnapshot(
            timestamp: Date(timeIntervalSince1970: timestamp),
            thermalState: .nominal,
            power: PowerSnapshot(batteryPercentage: nil, isCharging: nil, source: .unknown),
            processes: processes,
            sleepAssertions: sleepAssertions
        )
    }
}
