import Dispatch
import Foundation

// Dispatch delivers events off the main actor; the lock protects the only mutable state.
final class MemoryPressureObserver: @unchecked Sendable {
    private let lock = NSLock()
    private var latest = MemoryPressureState.unknown
    private let source: any DispatchSourceMemoryPressure

    var state: MemoryPressureState {
        lock.lock()
        defer { lock.unlock() }
        return latest
    }

    init() {
        source = DispatchSource.makeMemoryPressureSource(eventMask: .all,
            queue: DispatchQueue(label: "Why.memory-pressure", qos: .utility))
        source.setEventHandler { [weak self] in
            guard let self else { return }
            self.receive(self.source.data)
        }
        source.activate()
    }

    deinit { source.cancel() }

    func receive(_ event: DispatchSource.MemoryPressureEvent) {
        let state: MemoryPressureState
        if event.contains(.critical) { state = .critical }
        else if event.contains(.warning) { state = .warning }
        else if event.contains(.normal) { state = .normal }
        else { return }
        lock.lock()
        latest = state
        lock.unlock()
    }
}
