import Logging
import NIOConcurrencyHelpers

extension MQTTConnection {
    enum State {
        case idle
        case connecting
        case ready
        case waitingForReconnect
        case shutdown
    }
    
    class StateManager {
        
        // MARK: - Vars
        
        public let logger: Logger
        
        private let lock = Lock()
        private var _state: State = .idle
        private var _userInitiatedShutdown = false
        
        var state: State {
            get {
                return lock.withLock { _state }
            }
            set {
                lock.withLock { updateState(newValue) }
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
        
        // MARK: - Init
        
        init(logger: Logger) {
            self.logger = logger
        }
        
        // MARK: - User Shutdown
        
        func initiateUserShutdown() {
            lock.withLockVoid {
                logger.debug("User initiated shutdown")
                
                updateState(.shutdown)
                _userInitiatedShutdown = true
            }
        }
        
        // MARK: - Private
        
        private func updateState(_ newState: State) {
            guard !_userInitiatedShutdown, _state != newState else {
                logger.debug("Connection state change, ignoring because of user initiated shutdown", metadata: [
                    "state": "\(_state)",
                    "ignoredState": "\(newState)"
                ])
                return
            }
            
            let oldState = _state
            _state = newState
            
            logger.debug("Connection state change", metadata: [
                "oldState": "\(oldState)",
                "newState": "\(newState)"
            ])
        }
    }
}
