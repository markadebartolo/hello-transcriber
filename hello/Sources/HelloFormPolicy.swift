import Foundation

struct HelloFormField: Codable, Equatable, Sendable, Identifiable {
    let id: String
    let label: String
    let bounds: [Double]
}

struct HelloFormAssignment: Codable, Equatable, Sendable, Identifiable {
    var id: String { fieldID }
    let fieldID: String
    let text: String
}

struct HelloFormPlan: Codable, Equatable, Sendable {
    let assignments: [HelloFormAssignment]
    let needsReview: Bool
    let unassignedText: String
}

enum HelloFormPolicy {
    /// Model output is a proposal, never authority to choose arbitrary controls or
    /// invent content. Values must be verbatim spans of the captured transcript.
    static func validate(_ plan: HelloFormPlan, transcript: String, fields: [HelloFormField]) -> Bool {
        let allowed = Set(fields.map(\.id))
        var used = Set<String>()
        guard !plan.assignments.isEmpty, plan.assignments.count <= 30 else { return false }
        for assignment in plan.assignments {
            guard allowed.contains(assignment.fieldID), used.insert(assignment.fieldID).inserted,
                  !assignment.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  assignment.text.utf16.count <= 8000,
                  containsWholeSpan(assignment.text, in: transcript),
                  !assignment.text.unicodeScalars.contains(where: {
                      CharacterSet.controlCharacters.contains($0) && $0 != "\n" && $0 != "\t"
                  }) else { return false }
        }
        return true
    }

    /// Reject substrings that cut a name, identifier, signed amount, currency,
    /// decimal or percentage. Exact substring matching alone accepts "100" from
    /// "$1000"; overlapping token ranges close that gap.
    private static func containsWholeSpan(_ value: String, in transcript: String) -> Bool {
        let entire = NSRange(transcript.startIndex..., in: transcript)
        let patterns = [
            #"[\p{L}\p{M}\p{N}]+(?:['’\-@._+#/][\p{L}\p{M}\p{N}]+)*"#,
            #"[+−-]?[\p{Sc}]?\d(?:[\d,.]*\d)?(?:\s?%)?"#
        ]
        let tokens = patterns.flatMap { pattern in
            (try? NSRegularExpression(pattern: pattern))?.matches(in: transcript, range: entire).map(\.range) ?? []
        }
        var search = transcript.startIndex..<transcript.endIndex
        while let found = transcript.range(of: value, options: .literal, range: search) {
            let span = NSRange(found, in: transcript)
            if tokens.allSatisfy({ token in
                let overlap = NSIntersectionRange(span, token)
                return overlap.length == 0 || overlap == token
            }) { return true }
            guard found.lowerBound < transcript.endIndex else { break }
            search = transcript.index(after: found.lowerBound)..<transcript.endIndex
        }
        return false
    }

    static func mayAutomaticallyFill(_ plan: HelloFormPlan) -> Bool {
        !plan.needsReview && plan.unassignedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

/// Independently testable write sequencing. No rollback: an external app may have
/// accepted a write even when it cannot return verification, so report and stop.
enum HelloFormWriter {
    static func apply(_ assignments: [HelloFormAssignment],
                      validate: ([String: String]) -> Bool,
                      write: (HelloFormAssignment) -> Bool) -> (filled: Int, complete: Bool) {
        guard !assignments.isEmpty, Set(assignments.map(\.fieldID)).count == assignments.count else { return (0, false) }
        var written: [String: String] = [:]
        for assignment in assignments {
            guard validate(written), write(assignment) else { return (written.count, false) }
            written[assignment.fieldID] = assignment.text
        }
        return (written.count, true)
    }
}
