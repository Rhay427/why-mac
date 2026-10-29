import Foundation

enum PowerSource: String {
    case ac = "Power Adapter"
    case battery = "Battery"
    case unknown = "Unavailable"
}

enum BatteryHealth: String {
    case good = "Good"
    case fair = "Fair"
    case poor = "Poor"
}

struct PowerSnapshot {
    let batteryPercentage: Double?
    let isCharging: Bool?
    let source: PowerSource
    let isBatteryProvidingPower: Bool?
    let isExternalPowerAvailable: Bool?
    let batteryHealth: BatteryHealth?
    let isLowPowerModeEnabled: Bool

    init(
        batteryPercentage: Double?,
        isCharging: Bool?,
        source: PowerSource,
        isBatteryProvidingPower: Bool? = nil,
        isExternalPowerAvailable: Bool? = nil,
        batteryHealth: BatteryHealth? = nil,
        isLowPowerModeEnabled: Bool = false
    ) {
        self.batteryPercentage = batteryPercentage
        self.isCharging = isCharging
        self.source = source
        self.isBatteryProvidingPower = isBatteryProvidingPower
        self.isExternalPowerAvailable = isExternalPowerAvailable
        self.batteryHealth = batteryHealth
        self.isLowPowerModeEnabled = isLowPowerModeEnabled
    }
}

struct SystemSnapshot {
    let timestamp: Date
    let thermalState: ProcessInfo.ThermalState
    let power: PowerSnapshot
    let processes: [ProcessSnapshot]
    let processCollectionSucceeded: Bool
    let sleepAssertions: [SleepAssertionSnapshot]
    let sleepAssertionCollectionSucceeded: Bool
    let isDisplayAsleep: Bool?
    let memory: MemorySnapshot

    init(
        timestamp: Date,
        thermalState: ProcessInfo.ThermalState,
        power: PowerSnapshot,
        processes: [ProcessSnapshot],
        processCollectionSucceeded: Bool = true,
        sleepAssertions: [SleepAssertionSnapshot] = [],
        sleepAssertionCollectionSucceeded: Bool = true,
        isDisplayAsleep: Bool? = nil,
        memory: MemorySnapshot = MemorySnapshot()
    ) {
        self.timestamp = timestamp
        self.thermalState = thermalState
        self.power = power
        self.processes = processes
        self.processCollectionSucceeded = processCollectionSucceeded
        self.sleepAssertions = sleepAssertions
        self.sleepAssertionCollectionSucceeded = sleepAssertionCollectionSucceeded
        self.isDisplayAsleep = isDisplayAsleep
        self.memory = memory
    }
}
