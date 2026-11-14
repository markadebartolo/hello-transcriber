import Foundation

@main
struct HelloFormTests {
    static func main() throws {
        let fields = [HelloFormField(id: "name", label: "Name", bounds: [0,0,100,20]),
                      HelloFormField(id: "city", label: "City", bounds: [0,30,100,20])]
        let text = "Name Jean-Luc O’Neill, city Montréal. Budget $1,000.50, not $100."
        let assignments = [HelloFormAssignment(fieldID: "name", text: "Jean-Luc O’Neill"),
                           HelloFormAssignment(fieldID: "city", text: "Montréal")]
        let good = HelloFormPlan(assignments: assignments, needsReview: false, unassignedText: "")
        precondition(HelloFormPolicy.validate(good, transcript: text, fields: fields))
        precondition(HelloFormPolicy.mayAutomaticallyFill(good))
        let bad: [HelloFormPlan] = [
            .init(assignments: [.init(fieldID: "invented", text: "Jean-Luc O’Neill")], needsReview: false, unassignedText: ""),
            .init(assignments: [assignments[0], assignments[0]], needsReview: false, unassignedText: ""),
            .init(assignments: [.init(fieldID: "name", text: "Jean Luc O’Neill")], needsReview: false, unassignedText: ""),
            .init(assignments: [.init(fieldID: "name", text: "jean-Luc O’Neill")], needsReview: false, unassignedText: ""),
            .init(assignments: [.init(fieldID: "city", text: "$1000.50")], needsReview: false, unassignedText: ""),
            .init(assignments: [.init(fieldID: "name", text: "   ")], needsReview: false, unassignedText: ""),
            .init(assignments: [], needsReview: false, unassignedText: "")
        ]
        for plan in bad { precondition(!HelloFormPolicy.validate(plan, transcript: text, fields: fields)) }
        for fragment in ["Jean", "Neill", "1,000.50", "$1,000", "100", "Montr"] {
            let cut = HelloFormPlan(assignments: [.init(fieldID: "name", text: fragment)], needsReview: false, unassignedText: "")
            precondition(!HelloFormPolicy.validate(cut, transcript: text, fields: fields))
        }
        precondition(!HelloFormPolicy.mayAutomaticallyFill(.init(assignments: assignments, needsReview: true, unassignedText: "")))
        precondition(!HelloFormPolicy.mayAutomaticallyFill(.init(assignments: assignments, needsReview: false, unassignedText: "Budget $1,000.50")))
        var writes: [HelloFormAssignment] = []
        let stopped = HelloFormWriter.apply(assignments, validate: { _ in false }, write: { writes.append($0); return true })
        precondition(writes.isEmpty && !stopped.complete && stopped.filled == 0)
        let partial = HelloFormWriter.apply(assignments, validate: { $0.isEmpty }, write: { writes.append($0); return true })
        precondition(partial.filled == 1 && !partial.complete && writes == [assignments[0]])
        writes = []
        let failed = HelloFormWriter.apply(assignments, validate: { _ in true }, write: { writes.append($0); return false })
        precondition(failed.filled == 0 && !failed.complete && writes.count == 1)
        let success = HelloFormWriter.apply(assignments, validate: { state in
            state.isEmpty || state == ["name": "Jean-Luc O’Neill"]
        }, write: { _ in true })
        precondition(success.complete && success.filled == 2)
        let duplicate = HelloFormWriter.apply([assignments[0], assignments[0]], validate: { _ in fatalError("duplicate passed") }, write: { _ in true })
        precondition(!duplicate.complete)

        let body = try HelloFormPlanner.requestBody(transcript: text, fields: fields, image: Data([1,2,3]))
        let request = try JSONSerialization.jsonObject(with: body) as! [String: Any]
        precondition(request["store"] as? Bool == false && request["tools"] == nil)
        precondition(request["model"] as? String == "gpt-4.1-mini")
        let encoded = String(decoding: try JSONEncoder().encode(good), as: UTF8.self)
        func response(_ status: String, _ parts: [[String: String]]) throws -> Data {
            try JSONSerialization.data(withJSONObject: ["status": status, "output": [["type": "message", "content": parts]]])
        }
        let envelope = try response("completed", [["type": "output_text", "text": encoded]])
        let decoded = try HelloFormPlanner.decode(envelope, transcript: text, fields: fields)
        precondition(decoded == good)
        let invalidResponses = [
            try response("incomplete", [["type": "output_text", "text": encoded]]),
            try response("completed", [["type": "refusal", "refusal": "refused"]]),
            try response("completed", [["type": "output_text", "text": "not JSON"]]),
            try response("completed", [["type": "output_text", "text": encoded], ["type": "output_text", "text": encoded]]),
            try response("completed", [["type": "output_text", "text": String(decoding: try JSONEncoder().encode(bad[0]), as: UTF8.self)]])
        ]
        for invalid in invalidResponses {
            do { _ = try HelloFormPlanner.decode(invalid, transcript: text, fields: fields); fatalError("invalid response accepted") }
            catch { /* expected */ }
        }
        // Each service receives only its own authentication header and native
        // request format. Fake credentials never leave this test process.
        precondition(Set(HelloAIProvider.allCases.map(\.keychainService)).count == 3)
        precondition(HelloAIProvider.openAI.keychainService == "com.markdebartolo.hello.openai")
        for provider in HelloAIProvider.allCases {
            let apiRequest = try HelloFormPlanner.makeRequest(transcript: text, fields: fields, image: Data([1,2,3]),
                                                              key: "fixture-key-not-secret", provider: provider)
            precondition(apiRequest.url == provider.endpoint && apiRequest.httpMethod == "POST")
            let payload = try JSONSerialization.jsonObject(with: apiRequest.httpBody!) as! [String: Any]
            precondition(payload["model"] as? String == provider.model && payload["tools"] == nil)
            if provider == .anthropic {
                precondition(apiRequest.value(forHTTPHeaderField: "x-api-key") == "fixture-key-not-secret")
                precondition(apiRequest.value(forHTTPHeaderField: "Authorization") == nil)
                precondition(apiRequest.value(forHTTPHeaderField: "anthropic-version") == "2023-06-01")
                precondition(payload["messages"] != nil && payload["output_config"] != nil && payload["input"] == nil)
            } else {
                precondition(apiRequest.value(forHTTPHeaderField: "Authorization") == "Bearer fixture-key-not-secret")
                precondition(apiRequest.value(forHTTPHeaderField: "x-api-key") == nil)
                precondition(payload["store"] as? Bool == false && payload["input"] != nil && payload["messages"] == nil)
                let plan = try HelloFormPlanner.decode(envelope, transcript: text, fields: fields, provider: provider)
                precondition(plan == good)
            }
            if provider == .openRouter {
                let routing = payload["provider"] as! [String: Any]
                precondition(routing["require_parameters"] as? Bool == true)
                precondition(routing["data_collection"] as? String == "deny")
            }
        }
        func anthropicResponse(_ reason: String, _ content: [[String: String]]) throws -> Data {
            try JSONSerialization.data(withJSONObject: ["type": "message", "stop_reason": reason, "content": content])
        }
        let claude = try anthropicResponse("end_turn", [["type": "text", "text": encoded]])
        let claudePlan = try HelloFormPlanner.decode(claude, transcript: text, fields: fields, provider: .anthropic)
        precondition(claudePlan == good)
        for invalid in [
            try anthropicResponse("max_tokens", [["type": "text", "text": encoded]]),
            try anthropicResponse("refusal", [["type": "text", "text": encoded]]),
            try anthropicResponse("end_turn", [["type": "tool_use", "name": "run_command"]]),
            try anthropicResponse("end_turn", [["type": "text", "text": encoded], ["type": "text", "text": encoded]]),
            try anthropicResponse("end_turn", [["type": "text", "text": "broken JSON"]])
        ] {
            do { _ = try HelloFormPlanner.decode(invalid, transcript: text, fields: fields, provider: .anthropic); fatalError("invalid Anthropic output accepted") }
            catch { /* expected */ }
        }
        print("Form regressions passed: exact values, unknown/duplicate fields, ambiguity, interrupted/partial writes, three provider request/auth formats, isolated credential namespaces, request privacy, refusals and malformed/incomplete responses. No API call or UI interaction performed.")
    }
}
