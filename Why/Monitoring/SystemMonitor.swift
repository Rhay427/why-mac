import Combine
import CoreGraphics
import Foundation

@MainActor
final class SystemMonitor: ObservableObject {
    @Published private(set) var snapshot: SystemSnapshot
    @Published private(set) var diagnosis: Diagnosis
    @Published private(set) var sleepReminder: Diagnosis?
    @Published private(set) var contributors: DiagnosisContributors?
    @Published private(set) var isDiagnosing = false
    @Published private(set) var lastCheckedAt: Date?
    private(set) var activityContext = UserActivityContext.unknown
    private let processSensor: ProcessSensor
    private let memoryPressureObserver: MemoryPressureObserver
    private let activityProbe = UserActivityContextProbe()
    private static let observationWindow: Duration = .seconds(5)

    init() {
        let processSensor = ProcessSensor()
        let observer = MemoryPressureObserver()
        let snapshot = Self.captureSnapshot(processSensor: processSensor, memoryPressureObserver: observer)
        self.processSensor = processSensor
        self.memoryPressureObserver = observer
        self.snapshot = snapshot
        diagnosis = DiagnosisEngine().evaluate(snapshot)
        sleepReminder = nil
        contributors = nil
    }

    func refresh() async {
        guard !isDiagnosing else {
            return
        }

        isDiagnosing = true
        defer { isDiagnosing = false }
        sleepReminder = nil
        contributors = nil
        activityContext = .unknown
        let firstActivitySample = activityProbe.capture()

        let first = Self.captureSnapshot(processSensor: processSensor, memoryPressureObserver: memoryPressureObserver)
        snapshot = first
        diagnosis = DiagnosisEngine().evaluate(first)

        do {
            try await Task.sleep(for: Self.observationWindow)
        } catch {
            return
        }

        let second = Self.captureSnapshot(processSensor: processSensor,
            memoryPressureObserver: memoryPressureObserver, collectMemory: true)
        snapshot = second
        activityContext = activityProbe.context(
            between: firstActivitySample,
            and: activityProbe.capture()
        )
        let selection = DiagnosisRelevance().select(
            DiagnosisEngine().validDiagnoses(first, second),
            context: activityContext
        )
        diagnosis = selection.primary
        sleepReminder = selection.sleepReminder
        contributors = DiagnosisContributors.make(selection: selection, first: first, second: second)
        lastCheckedAt = second.timestamp
    }

    private static func captureSnapshot(processSensor: ProcessSensor,
        memoryPressureObserver: MemoryPressureObserver, collectMemory: Bool = false) -> SystemSnapshot {
        let processResult = processSensor.read()
        let sleepResult = SleepAssertionSensor().read()
        return SystemSnapshot(
            timestamp: Date(),
            thermalState: ThermalSensor().read(),
            power: PowerSensor().read(),
            processes: processResult.processes,
            processCollectionSucceeded: processResult.succeeded,
            sleepAssertions: sleepResult.assertions,
            sleepAssertionCollectionSucceeded: sleepResult.succeeded,
            isDisplayAsleep: CGDisplayIsAsleep(CGMainDisplayID()) != 0,
            memory: collectMemory ? MemorySensor().read(pressure: { memoryPressureObserver.state })
                : MemorySnapshot(pressure: memoryPressureObserver.state)
        )
    }
}
