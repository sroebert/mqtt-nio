import Foundation

extension Collection {
    /// Returns `self` if not empty, `nil` otherwise.
    var selfIfNotEmpty: Self? {
        guard !isEmpty else {
            return nil
        }
        return self
    }
}
