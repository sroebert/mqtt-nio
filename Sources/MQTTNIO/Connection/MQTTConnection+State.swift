import Logging
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
        
        public let logger: Logger
        
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
                let callDelegate = lock.withLock { updateState(newValue) }
                callDelegate()
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
            let callDelegate: () -> Void = lock.withLock {
                logger.debug("User initiated shutdown")
                
                let returnValue = updateState(.shutdown)
                _userInitiatedShutdown = true
                return returnValue
            }
            callDelegate()
        }
        
        // MARK: - Private
        
        @discardableResult
        private func updateState(_ newState: State) -> () -> Void {
            guard !_userInitiatedShutdown, _state != newState else {
                logger.debug("Connection state change, ignoring because of user initiated shutdown", metadata: [
                    "state": "\(_state)",
                    "ignoredState": "\(newState)"
                ])
                return {}
            }
            
            let oldState = _state
            _state = newState
            
            logger.debug("Connection state change", metadata: [
                "oldState": "\(oldState)",
                "newState": "\(newState)"
            ])
            
            return {
                guard let connection = self.connection else {
                    return
                }
                self._delegate?.mqttConnection(connection, didChangeFrom: oldState, to: newState)
            }
        }
    }
}
