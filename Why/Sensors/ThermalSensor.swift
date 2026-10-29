import Foundation

struct ThermalSensor {
    func read() -> ProcessInfo.ThermalState {
        ProcessInfo.processInfo.thermalState
    }
}
