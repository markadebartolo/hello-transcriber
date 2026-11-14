//
//  OnDeviceModel.swift
//  leanring-buddy
//
//  Apple's built-in on-device model (Foundation Models, macOS 26+) for Dorsal's cheap,
//  deterministic helper calls — private, near-instant, free, no download, and it draws
//  ZERO API credit. Used as a FIRST TRY for low-stakes, bounded text helpers (a one-line
//  summary, a small classification/extraction); every caller keeps its existing
//  Worker/Haiku call as the automatic fallback (macOS 14/15, model not yet ready, or any
//  failure). Never the vision / agent / reasoning path — those need frontier quality and
//  stay on Claude.
//

import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

enum OnDeviceModel {
    /// True when Apple's on-device model is ready right now (macOS 26+, supported
    /// hardware, model downloaded, Apple Intelligence on).
    static var isAvailable: Bool {
        #if canImport(FoundationModels)
        if #available(macOS 26.0, *) {
            if case .available = SystemLanguageModel.default.availability { return true }
        }
        #endif
        return false
    }

    /// One-shot instructions + prompt → text on the on-device model. Returns nil when the
    /// model is unavailable or on ANY error, so the caller falls back to the API. Best for
    /// short, bounded helper tasks — not reasoning, world knowledge, or long context.
    static func respond(instructions: String, prompt: String) async -> String? {
        #if canImport(FoundationModels)
        if #available(macOS 26.0, *) {
            guard case .available = SystemLanguageModel.default.availability else { return nil }
            do {
                let session = LanguageModelSession(instructions: instructions)
                let response = try await session.respond(to: prompt)
                let text = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
                return text.isEmpty ? nil : text
            } catch {
                return nil
            }
        }
        #endif
        return nil
    }
}
