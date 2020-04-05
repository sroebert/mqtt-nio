import NIO
import NIOConcurrencyHelpers

class CallbackList<Arguments> {
    
    // MARK: - Types
    
    typealias Callback = (Arguments, Entry) -> Void
    
    class Entry {
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
    
    private var _eventLoop: EventLoop
    var eventLoop: EventLoop {
        get {
            return lock.withLock { _eventLoop }
        }
        set {
            lock.withLockVoid {
                _eventLoop = newValue
            }
        }
    }
    
    private var callbackEntries: [Entry] = []
    private let lock = Lock()
    
    // MARK: - Init
    
    init(eventLoop: EventLoop) {
        _eventLoop = eventLoop
    }
    
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
        let (eventLoop, entries) = lock.withLock { (_eventLoop, callbackEntries) }
        eventLoop.execute {
            entries.forEach { $0.callback(arguments, $0) }
        }
    }
}
