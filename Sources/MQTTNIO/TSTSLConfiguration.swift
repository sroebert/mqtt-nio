#if canImport(Network)

import Foundation
import Network
import Logging

public enum TSTLSVersion: MQTTSendable {
    case tlsv1
    case tlsv11
    case tlsv12
    case tlsv13

    var sslProtocol: SSLProtocol {
        switch self {
        case .tlsv1:
            return .tlsProtocol1
        case .tlsv11:
            return .tlsProtocol11
        case .tlsv12:
            return .tlsProtocol12
        case .tlsv13:
            return .tlsProtocol13
        }
    }

    @available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
    var tlsProtocolVersion: tls_protocol_version_t {
        switch self {
        case .tlsv1:
            return .TLSv10
        case .tlsv11:
            return .TLSv11
        case .tlsv12:
            return .TLSv12
        case .tlsv13:
            return .TLSv13
        }
    }
}

public enum TSCertificateVerification: MQTTSendable {
    /// All certificate verification disabled.
    case none

    /// Certificates will be validated against the trust store, but will not
    /// be checked to see if they are valid for the given hostname.
    case noHostnameVerification

    /// Certificates will be validated against the trust store and checked
    /// against the hostname of the service we are contacting.
    case fullVerification
}

public enum TSTrustRoots {
    /// The system default root of trust.
    case `default`
    
    /// A list of certificates.
    case certificates([SecCertificate])
}

#if swift(>=5.5) && canImport(_Concurrency)
extension TSTrustRoots: @unchecked MQTTSendable {}
#endif

public struct TSTLSConfiguration {
    
    /// The minimum TLS version to allow in negotiation. Defaults to tlsv1.
    public var minimumTLSVersion: TSTLSVersion

    /// The maximum TLS version to allow in negotiation. If nil, there is no upper limit. Defaults to nil.
    public var maximumTLSVersion: TSTLSVersion?
    
    /// Whether to verify remote certificates.
    public var certificateVerification: TSCertificateVerification
    
    /// The trust roots to use to validate certificates. This only needs to be provided if you intend to validate
    /// certificates.
    ///
    /// - NOTE: If certificate validation is enabled and `trustRoots` is `nil` then the system default root of
    /// trust is used (as if `trustRoots` had been explicitly set to `.default`).
    public var trustRoots: TSTrustRoots?
    
    /// The local identity to present in the TLS handshake. Defaults to `nil`.
    public var clientIdentity: SecIdentity?
    
    /// The certificates chain to use for the local identity to present in the TLS handshake. Defaults to `nil`.
    public var clientIdentityCertificates: [SecCertificate]?
    
    /// The application protocols to use in the connection. Should be an ordered list of ASCII
    /// strings representing the ALPN identifiers of the protocols to negotiate. For clients,
    /// the protocols will be offered in the order given. For servers, the protocols will be matched
    /// against the client's offered protocols in order.
    public var applicationProtocols: [String]
    
    /// Creates an `TSTLSConfiguration`.
    /// - Parameters:
    ///   - minimumTLSVersion: The minimum TLS version to allow in negotiation. Defaults to tlsv1.
    ///   - maximumTLSVersion: The maximum TLS version to allow in negotiation. If nil, there is no upper limit. Defaults to nil.
    ///   - certificateVerification: Whether to verify remote certificates. Defaults to full verification.
    ///   - trustRoots: The trust roots to use to validate certificates. This only needs to be provided if you intend to validate certificates.
    ///   - clientIdentity: The local identity to present in the TLS handshake. Defaults to nil.
    ///   - clientIdentityCertificates: The certificates chain to use for the local identity to present in the TLS handshake. Defaults to `nil`.
    ///   - applicationProtocols: The application protocols to use in the connection.
    @available(OSX 10.14, iOS 12.0, tvOS 12.0, watchOS 6.0, *)
    public init(
        minimumTLSVersion: TSTLSVersion = .tlsv1,
        maximumTLSVersion: TSTLSVersion? = nil,
        certificateVerification: TSCertificateVerification = .fullVerification,
        trustRoots: TSTrustRoots? = nil,
        clientIdentity: SecIdentity? = nil,
        clientIdentityCertificates: [SecCertificate]? = nil,
        applicationProtocols: [String] = []
    ) {
        self.minimumTLSVersion = minimumTLSVersion
        self.maximumTLSVersion = maximumTLSVersion
        self.trustRoots = trustRoots
        self.clientIdentity = clientIdentity
        self.clientIdentityCertificates = clientIdentityCertificates
        self.applicationProtocols = applicationProtocols
        self.certificateVerification = certificateVerification
    }
    
    // MARK: - Options
    
    static let tlsVerifyQueue = DispatchQueue(label: "MQTTNIO.tlsVerifyQueue")
    
    @available(OSX 10.14, iOS 12.0, tvOS 12.0, watchOS 6.0, *)
    func createNWProtocolTLSOptions(tlsServerName: String?, logger: Logger) -> NWProtocolTLS.Options {
        let options = NWProtocolTLS.Options()

        if #available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *) {
            sec_protocol_options_set_min_tls_protocol_version(options.securityProtocolOptions, minimumTLSVersion.tlsProtocolVersion)
        } else {
            sec_protocol_options_set_tls_min_version(options.securityProtocolOptions, minimumTLSVersion.sslProtocol)
        }

        if let maximumTLSVersion = maximumTLSVersion {
            if #available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *) {
                sec_protocol_options_set_max_tls_protocol_version(options.securityProtocolOptions, maximumTLSVersion.tlsProtocolVersion)
            } else {
                sec_protocol_options_set_tls_max_version(options.securityProtocolOptions, maximumTLSVersion.sslProtocol)
            }
        }
        
        switch (clientIdentity, clientIdentityCertificates) {
        case (let clientIdentity?, nil):
            if let secIdentity = sec_identity_create(clientIdentity) {
                sec_protocol_options_set_local_identity(options.securityProtocolOptions, secIdentity)
            }
            
        case (let clientIdentity?, let certificates?):
            if let secIdentity = sec_identity_create_with_certificates(clientIdentity, certificates as CFArray) {
                sec_protocol_options_set_local_identity(options.securityProtocolOptions, secIdentity)
            }
            
        default:
            break
        }

        for applicationProtocol in applicationProtocols {
            sec_protocol_options_add_tls_application_protocol(options.securityProtocolOptions, applicationProtocol)
        }
        
        if let tlsServerName = tlsServerName {
            sec_protocol_options_set_tls_server_name(options.securityProtocolOptions, tlsServerName)
        }
        
        sec_protocol_options_set_verify_block(
            options.securityProtocolOptions,
            { metadata, secTrust, completion in
                switch certificateVerification {
                case .none:
                    completion(true)
                    
                case .noHostnameVerification, .fullVerification:
                    let trust = sec_trust_copy_ref(secTrust).takeRetainedValue()
                    if case .certificates(let certificates) = trustRoots {
                        SecTrustSetAnchorCertificates(trust, certificates as CFArray)
                    }
                    
                    if certificateVerification == .noHostnameVerification {
                        let policy = SecPolicyCreateBasicX509()
                        SecTrustSetPolicies(trust, policy)
                    }
                    
                    if #available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *) {
                        SecTrustEvaluateAsyncWithError(trust, Self.tlsVerifyQueue) { _, result, error in
                            if let error = error {
                                logger.error("Certificate validation failed", metadata: [
                                    "error": "\(error)"
                                ])
                            }
                            completion(result)
                        }
                    } else {
                        SecTrustEvaluateAsync(trust, Self.tlsVerifyQueue) { _, result in
                            switch result {
                            case .proceed, .unspecified:
                                completion(true)
                            default:
                                logger.error("Certificate validation failed", metadata: [
                                    "result": "\(result)"
                                ])
                                completion(false)
                            }
                        }
                    }
                }
            },
            Self.tlsVerifyQueue
        )
        
        return options
    }
}

#if swift(>=5.5) && canImport(_Concurrency)
extension TSTLSConfiguration: @unchecked MQTTSendable {}
#endif

#endif
