/// Cancellable object received when registering an observer callback with an `MQTTClient`.
///
/// This object allows to stop receiving callbacks by calling `cancel`.
///
/// - Note: `cancel` is not automatically called when not retaining this cancellable object.
/// Callbacks can only be cancelled if you keep a reference to the returned `MQTTCancellable`.
public protocol MQTTCancellable: MQTTPreconcurrencySendable {
    /// Stops the callback from being called.
    func cancel()
}

extension CallbackList.Entry: MQTTCancellable {
    func cancel() {
        remove()
    }
}
