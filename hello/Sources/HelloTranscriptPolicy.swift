import Foundation

enum HelloTranscriptPolicy {
    /// A conservative guard for a REVIEW-ONLY suggestion. Token equality cannot
    /// prove meaning: "Let's eat, Grandma" is different from "Let's eat Grandma".
    /// Therefore the controller never automatically inserts model cleanup.
    static func acceptedCleanup(_ candidate: String?, original: String) -> String {
        guard let candidate else { return original }
        let trimmed = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              words(trimmed) == words(original),
              numericExpressions(trimmed) == numericExpressions(original),
              protectedCharacters(trimmed) == protectedCharacters(original) else { return original }
        return trimmed
    }

    private static func words(_ text: String) -> [String] {
        // Case is intentional: names, acronyms, identifiers, accents and word
        // boundaries must survive exactly, including contractions and hyphens.
        matches(#"[\p{L}\p{M}\p{N}]+(?:['’\-][\p{L}\p{M}\p{N}]+)*"#, in: text)
    }

    private static func numericExpressions(_ text: String) -> [String] {
        matches(#"[+−-]?[\p{Sc}]?\d(?:[\d,.]*\d)?(?:\s?%)?"#, in: text)
    }

    private static func protectedCharacters(_ text: String) -> String {
        let allowed = CharacterSet.letters.union(.decimalDigits).union(.nonBaseCharacters)
            .union(CharacterSet(charactersIn: " \t.,!?，。！？"))
        return String(String.UnicodeScalarView(text.unicodeScalars.filter { !allowed.contains($0) }))
    }

    private static func matches(_ pattern: String, in text: String) -> [String] {
        guard let expression = try? NSRegularExpression(pattern: pattern) else { return [] }
        return expression.matches(in: text, range: NSRange(text.startIndex..., in: text)).compactMap {
            Range($0.range, in: text).map { String(text[$0]) }
        }
    }
}
