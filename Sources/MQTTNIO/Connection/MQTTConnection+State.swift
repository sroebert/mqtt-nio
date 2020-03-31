import NIOConcurrencyHelpers

extension MQTTConnection {
    enum State {
        case idle
        case connecting
        case ready
        case transientFailure
        case shutdown
    }
    
    class StateManager {
        
        // MARK: - Vars
        
        private let lock = Lock()
        private var _state: State = .idle
        private var _userInitiatedShutdown = false
        
        weak var connection: MQTTConnection?
        weak var _delegate: MQTTConnectionStateDelegate?
        
        var delegate: MQTTConnectionStateDelegate? {
            get {
                return lock.withLock { _delegate }
            }
            set {
                lock.withLockVoid {
                    _delegate = newValue
                }
            }
        }
        
        var state: State {
            get {
                return lock.withLock { _state }
            }
            set {
                lock.withLockVoid {
                    updateState(newValue)
                }
            }
        }
        
        var userHasInitiatedShutdown: Bool {
            return lock.withLock { _userInitiatedShutdown }
        }
        
        var canReconnect: Bool {
            return lock.withLock {
                !_userInitiatedShutdown && _state == .ready
            }
        }
        
        // MARK: - User Shutdown
        
        func initiateUserShutdown() {
            lock.withLockVoid {
                updateState(.shutdown)
                _userInitiatedShutdown = true
            }
        }
        
        // MARK: - Private
        
        private func updateState(_ newState: State) {
            guard !_userInitiatedShutdown, _state != newState else {
                return
            }
            
            let oldState = _state
            _state = newState
            
            guard let connection = connection else {
                return
            }
            _delegate?.mqttConnection(connection, didChangeFrom: oldState, to: newState)
        }
    }
}
