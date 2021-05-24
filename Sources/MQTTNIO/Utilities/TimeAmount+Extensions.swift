import NIO

extension TimeAmount {
    var seconds: Int64 {
        return nanoseconds / TimeAmount.seconds(1).nanoseconds
    }
}
