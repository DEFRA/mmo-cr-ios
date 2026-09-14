//
//  AppEnvironment.swift
//  record-catch
//
//  Created by Paul Halpin on 08/07/2026.
//

import Foundation

@Observable
final class AppEnvironment {
    init() {
        // Intentionally empty: no shared app-wide state to initialise yet — this environment
        // object exists as a seam for future cross-feature state (see ADR-0001 pattern).
    }
}
