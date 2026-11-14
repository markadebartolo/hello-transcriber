import Foundation

enum HelloTranscriptPolicy {
    /// Cleanup is allowed to change punctuation/casing, not the words, numbers, or
    /// their order. This keeps dictated financial amounts and names from being rewritten.
    static func acceptedCleanup(_ candidate: String?, original: String) -> String {
        guard let candidate else { return original }
        let trimmedCandidate = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedCandidate.isEmpty,
              lexicalContent(trimmedCandidate) == lexicalContent(original),
              numericExpressions(trimmedCandidate) == numericExpressions(original) else { return original }
        return trimmedCandidate
    }

    private static func lexicalContent(_ text: String) -> [String] {
        text.lowercased().components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }
    }

    private static func numericExpressions(_ text: String) -> [String] {
        let pattern = #"[+−-]?[$€£¥]?\d(?:[\d,.]*\d)?(?:\s?%)?"#
        guard let expression = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return expression.matches(in: text, range: range).compactMap { match in
            Range(match.range, in: text).map { String(text[$0]) }
        }
    }
}
