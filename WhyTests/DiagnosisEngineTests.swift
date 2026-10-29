import XCTest
@testable import Why

final class DiagnosisEngineTests: XCTestCase {
    func testSuccessfulEmptyRequiredCollectionsRemainHealthy() {
        let diagnosis = selectedDiagnosis(
            first: snapshot(timestamp: 0),
            second: snapshot(timestamp: 5)
        )

        guard case .healthy = diagnosis else {
            return XCTFail("Successful empty required collections should support Healthy")
        }
    }

    func testProcessCollectionFailureMakesOtherwiseEmptyCheckInconclusive() {
        XCTAssertEqual(
            selectedDiagnosis(
                first: snapshot(timestamp: 0, processCollectionSucceeded: false),
                second: snapshot(timestamp: 5)
            ),
            .inconclusive
        )
    }

    func testSleepAssertionCollectionFailureMakesOtherwiseEmptyCheckInconclusive() {
        XCTAssertEqual(
            selectedDiagnosis(
                first: snapshot(timestamp: 0),
                second: snapshot(timestamp: 5, sleepAssertionCollectionSucceeded: false)
            ),
            .inconclusive
        )
    }

    func testThermalDiagnosisWinsDespiteProcessCollectionFailure() {
        let diagnosis = selectedDiagnosis(
            first: snapshot(timestamp: 0, processCollectionSucceeded: false),
            second: snapshot(
                timestamp: 5,
                thermalState: .serious,
                processCollectionSucceeded: false
            )
        )

        guard case let .issue(_, title, _) = diagnosis else {
            return XCTFail("Independent thermal evidence should remain actionable")
        }
        XCTAssertEqual(title, "Your Mac is running hot")
    }

    func testMemoryDiagnosisWinsDespiteSleepCollectionFailure() {
        let diagnosis = selectedDiagnosis(
            first: snapshot(timestamp: 0),
            second: snapshot(
                timestamp: 5,
                sleepAssertionCollectionSucceeded: false,
                memory: MemorySnapshot(pressure: .warning)
            )
        )

        guard case let .issue(_, title, _) = diagnosis else {
            return XCTFail("Independent memory evidence should remain actionable")
        }
        XCTAssertEqual(title, "Memory pressure")
    }

    func testBatteryObservationUnavailableDoesNotForceGenericInconclusive() {
        let power = PowerSnapshot(
            batteryPercentage: nil,
            isCharging: nil,
            source: .unknown,
            isBatteryProvidingPower: nil,
            isExternalPowerAvailable: nil
        )

        let diagnosis = selectedDiagnosis(
            first: snapshot(timestamp: 0, power: power),
            second: snapshot(timestamp: 60, power: power)
        )

        guard case .healthy = diagnosis else {
            return XCTFail("Unavailable battery enrichment should not poison the generic check")
        }
    }

    func testUnknownMemoryPressureDoesNotForceGenericInconclusive() {
        let diagnosis = selectedDiagnosis(
            first: snapshot(timestamp: 0),
            second: snapshot(timestamp: 5, memory: MemorySnapshot(pressure: .unknown))
        )

        guard case .healthy = diagnosis else {
            return XCTFail("Unknown memory pressure should preserve the existing contract")
        }
    }

    func testValidDiagnosisPriorityIsUnchangedWhenCollectorsFail() {
        let diagnosis = selectedDiagnosis(
            first: snapshot(timestamp: 0, processCollectionSucceeded: false),
            second: snapshot(
                timestamp: 5,
                thermalState: .serious,
                processCollectionSucceeded: false,
                sleepAssertionCollectionSucceeded: false,
                memory: MemorySnapshot(pressure: .critical)
            )
        )

        guard case let .issue(_, title, _) = diagnosis else {
            return XCTFail("A valid diagnosis should win over collection status")
        }
        XCTAssertEqual(title, "Your Mac is running hot")
    }

    func testThermalPressureChangesHealthyDiagnosisToWarning() {
        let power = PowerSnapshot(batteryPercentage: nil, isCharging: nil, source: .unknown)
        let nominal = SystemSnapshot(
            timestamp: Date(timeIntervalSince1970: 0),
            thermalState: .nominal,
            power: power,
            processes: []
        )
        let serious = SystemSnapshot(
            timestamp: Date(timeIntervalSince1970: 1),
            thermalState: .serious,
            power: power,
            processes: []
        )

        guard case .healthy = DiagnosisEngine().evaluate(nominal) else {
            return XCTFail("Nominal thermal state should be explicitly healthy")
        }

        guard case let .issue(severity, _, _) = DiagnosisEngine().evaluate(serious) else {
            return XCTFail("Serious thermal pressure should produce an issue")
        }
        XCTAssertEqual(severity, .warning)
    }

    func testTwoSnapshotEvaluationIncludesSustainedCPUProcess() {
        let power = PowerSnapshot(batteryPercentage: nil, isCharging: nil, source: .unknown)
        let first = SystemSnapshot(
            timestamp: Date(timeIntervalSince1970: 0),
            thermalState: .nominal,
            power: power,
            processes: [ProcessSnapshot(pid: 100, name: "Xcode", cpuUsage: 80)]
        )
        let second = SystemSnapshot(
            timestamp: Date(timeIntervalSince1970: 5),
            thermalState: .nominal,
            power: power,
            processes: [ProcessSnapshot(pid: 100, name: "Xcode", cpuUsage: 75)]
        )

        guard case let .issue(_, _, explanation) = DiagnosisEngine().evaluate(first, second) else {
            return XCTFail("Two-snapshot evaluation should include a sustained CPU diagnosis")
        }

        XCTAssertEqual(explanation, "Xcode is currently the main source of sustained processor activity.")
    }

    func testCurrentSnapshotEvaluationIncludesSleepBlocker() {
        let snapshot = SystemSnapshot(
            timestamp: Date(timeIntervalSince1970: 0),
            thermalState: .nominal,
            power: PowerSnapshot(batteryPercentage: nil, isCharging: nil, source: .unknown),
            processes: [],
            sleepAssertions: [
                SleepAssertionSnapshot(
                    pid: 100,
                    assertionType: "PreventUserIdleSystemSleep",
                    name: nil,
                    humanReadableReason: nil,
                    details: nil,
                    level: 255,
                    applicationIdentity: nil,
                    processDisplayName: "caffeinate"
                )
            ]
        )

        guard case let .issue(_, _, explanation) = DiagnosisEngine().evaluate(snapshot) else {
            return XCTFail("Current snapshot evaluation should include a sleep diagnosis")
        }

        XCTAssertEqual(explanation, "caffeinate is currently preventing automatic idle sleep.")
    }

    private func selectedDiagnosis(first: SystemSnapshot, second: SystemSnapshot) -> Diagnosis {
        DiagnosisRelevance().select(
            DiagnosisEngine().validDiagnoses(first, second),
            context: .unknown
        ).primary
    }

    private func snapshot(
        timestamp: TimeInterval,
        thermalState: ProcessInfo.ThermalState = .nominal,
        power: PowerSnapshot? = nil,
        processCollectionSucceeded: Bool = true,
        sleepAssertionCollectionSucceeded: Bool = true,
        memory: MemorySnapshot = MemorySnapshot()
    ) -> SystemSnapshot {
        SystemSnapshot(
            timestamp: Date(timeIntervalSince1970: timestamp),
            thermalState: thermalState,
            power: power ?? PowerSnapshot(
                batteryPercentage: nil,
                isCharging: nil,
                source: .ac,
                isBatteryProvidingPower: false,
                isExternalPowerAvailable: true
            ),
            processes: [],
            processCollectionSucceeded: processCollectionSucceeded,
            sleepAssertionCollectionSucceeded: sleepAssertionCollectionSucceeded,
            memory: memory
        )
    }
}
