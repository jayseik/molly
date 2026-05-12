import Foundation

/// Build-time SKU toggle. XcodeGen enables `MOLLY_SKU_DIRECT` by default; remove that flag when archiving for Mac App Store.
enum MollySKU {
    #if MOLLY_SKU_DIRECT
    static let isDirectDistribution: Bool = true
    static let displayName = "Developer ID (Sparkle-eligible)"
    #else
    static let isDirectDistribution: Bool = false
    static let displayName = "Mac App Store (sandbox probes)"
    #endif

    static var connectivityNarrative: String {
        isDirectDistribution
            ? "Direct SKU may expand to privileged ICMP helpers later; v1 probes stay TCP + HTTPS sandbox-friendly transports."
            : "MAS SKU probes use outbound networking only—no privileged ICMP helper in v1."
    }
}
