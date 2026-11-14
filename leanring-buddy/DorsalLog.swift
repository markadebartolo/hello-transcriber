//
//  DorsalLog.swift
//  leanring-buddy
//
//  Lightweight diagnostic logging that compiles to nothing in Release builds, so
//  beta testers don't get Dorsal's internal chatter (permission states, token
//  lengths, TTS sizes…) in Console.app. This replaces the app's ad-hoc print()
//  calls; the signature mirrors Swift's `print` so call sites are identical.
//

import Foundation

/// Debug-only logger. In Release the body is empty — the call does nothing. In
/// Debug it forwards to `print` with the same default separator/terminator.
@inline(__always)
func DorsalLog(
    _ items: Any...,
    separator: String = " ",
    terminator: String = "\n"
) {
    #if DEBUG
    print(items.map { "\($0)" }.joined(separator: separator), terminator: terminator)
    #endif
}
