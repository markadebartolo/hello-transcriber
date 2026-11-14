import ApplicationServices

@main
struct HelloTextFieldTests {
    static func main() {
        func accepts(role: String? = kAXTextAreaRole, subrole: String? = nil,
                     enabled: Bool? = true, error: AXError = .success,
                     writable: Bool = true) -> Bool {
            HelloTextFieldEligibility.accepts(role: role, subrole: subrole,
                enabled: enabled, enabledError: error, selectionWritable: writable)
        }
        precondition(accepts())
        precondition(accepts(enabled: nil, error: .attributeUnsupported),
                     "A native writable text view may omit AXEnabled")
        precondition(accepts(enabled: nil, error: .noValue))
        precondition(!accepts(enabled: false))
        precondition(!accepts(enabled: nil), "Malformed successful values fail closed")
        precondition(!accepts(enabled: nil, error: .cannotComplete))
        precondition(!accepts(enabled: nil, error: .apiDisabled))
        precondition(!accepts(writable: false))
        precondition(!accepts(enabled: nil, error: .attributeUnsupported, writable: false))
        precondition(!accepts(role: kAXStaticTextRole))
        precondition(!accepts(role: nil))
        precondition(!accepts(subrole: kAXSecureTextFieldSubrole))
        precondition(!accepts(subrole: kAXSecureTextFieldSubrole, enabled: nil, error: .attributeUnsupported))
        print("Hello text-field eligibility: 13 writable, omitted, disabled, secure and failed-query cases passed")
    }
}
