import Foundation
import IOKit.ps

struct PowerSensor {
    func read() -> PowerSnapshot {
        // IOPS exposes aggregate capacity and charging state, but not reliable real-time wattage.
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue() else {
            return PowerSnapshot(
                batteryPercentage: nil,
                isCharging: nil,
                source: .unknown,
                isLowPowerModeEnabled: ProcessInfo.processInfo.isLowPowerModeEnabled
            )
        }

        let source: PowerSource
        switch IOPSGetProvidingPowerSourceType(info)?.takeUnretainedValue() as String? {
        case kIOPSACPowerValue:
            source = .ac
        case kIOPSBatteryPowerValue:
            source = .battery
        default:
            source = .unknown
        }

        // Adapter details are independent evidence. nil is unknown because some attached adapters omit details.
        let externalPowerAvailable = IOPSCopyExternalPowerAdapterDetails()?.takeRetainedValue() == nil ? nil : true

        guard
            let powerSources = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [AnyObject],
            let battery = powerSources.lazy.compactMap({ powerSource -> [String: Any]? in
                guard
                    let description = IOPSGetPowerSourceDescription(info, powerSource)?.takeUnretainedValue() as? [String: Any],
                    description[kIOPSTypeKey] as? String == kIOPSInternalBatteryType
                else {
                    return nil
                }
                return description
            }).first
        else {
            return PowerSnapshot(
                batteryPercentage: nil,
                isCharging: nil,
                source: source,
                isExternalPowerAvailable: externalPowerAvailable,
                isLowPowerModeEnabled: ProcessInfo.processInfo.isLowPowerModeEnabled
            )
        }

        let currentCapacity = (battery[kIOPSCurrentCapacityKey] as? NSNumber)?.doubleValue
        let maximumCapacity = (battery[kIOPSMaxCapacityKey] as? NSNumber)?.doubleValue
        let percentage = currentCapacity.flatMap { current in
            maximumCapacity.flatMap { maximum in maximum > 0 ? current / maximum * 100 : nil }
        }
        let isBatteryProvidingPower: Bool?
        switch battery[kIOPSPowerSourceStateKey] as? String {
        case kIOPSBatteryPowerValue:
            isBatteryProvidingPower = true
        case kIOPSACPowerValue:
            isBatteryProvidingPower = false
        default:
            isBatteryProvidingPower = nil
        }

        return PowerSnapshot(
            batteryPercentage: percentage,
            isCharging: battery[kIOPSIsChargingKey] as? Bool,
            source: source,
            isBatteryProvidingPower: isBatteryProvidingPower,
            isExternalPowerAvailable: externalPowerAvailable,
            batteryHealth: (battery[kIOPSBatteryHealthKey] as? String).flatMap(BatteryHealth.init(rawValue:)),
            isLowPowerModeEnabled: ProcessInfo.processInfo.isLowPowerModeEnabled
        )
    }
}
