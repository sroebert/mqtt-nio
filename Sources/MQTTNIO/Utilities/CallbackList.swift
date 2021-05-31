import Dispatch
import NIO
import NIOConcurrencyHelpers

final class CallbackList<Arguments> {
    
    // MARK: - Types
    
    typealias Callback = (Arguments) -> Void
    
    final class Entry {
        weak var list: CallbackList<Arguments>?
        let callback: Callback
        
        init(list: CallbackList<Arguments>, callback: @escaping Callback) {
            self.list = list
            self.callback = callback
        }
        
        func remove() {
            list?.remove(self)
        }
    }
    
    // MARK: - Vars
    
    private var callbackEntries: [Entry] = []
    private let lock = Lock()
    
    // MARK: - Callbacks
    
    func append(_ callback: @escaping Callback) -> Entry {
        return lock.withLock {
            let entry = Entry(list: self, callback: callback)
            callbackEntries.append(entry)
            return entry
        }
    }
    
    private func remove(_ entry: Entry) {
        lock.withLockVoid {
            if let index = callbackEntries.firstIndex(where: { $0 === entry }) {
                callbackEntries.remove(at: index)
            }
        }
    }
    
    func emit(arguments: Arguments) {
        let entries = lock.withLock { callbackEntries }
        DispatchQueue.main.async {
            entries.forEach { $0.callback(arguments) }
        }
    }
}
