//
//  CatchRecordReference.swift
//  record-catch
//
//  Client-generated catch record reference (ADR-0026): created once, locally, the moment a user
//  confirms their vessel on the Select vessel screen — not server-assigned. Format:
//  `{RSS}-{DDMMYYYY}-{HHMMSS}`, e.g. `A12345-27072026-150815`.
//
//  ⚠️ The Catch Recording Service's `CreateDraftCatchRecordPayload.catchRecordReference` field
//  currently validates references against `^GBR-[A-Z0-9]+-\d{6}-\d{6}$` (a 2-digit year, "GBR"
//  prefix) — this generator deliberately does **not** match that pattern (see ADR-0026). Sending
//  this reference to `POST /v1/catch-records` will be rejected by the service with `422`/`400`
//  until the backend team updates their validation to accept this format. See
//  `CatchRecordServicesFactory`/ADR-0025 for how that dependency is tracked.
//

import Foundation

/// Builds the client-generated catch record reference for a newly-selected vessel.
///
/// A pure function of its inputs (RSS number + a point in time) so it is trivially unit-testable
/// without constructing a `Date`/timezone by hand at every call site, and so the exact format can
/// change in one place if the backend's accepted pattern changes later (see the file-level
/// warning above).
nonisolated struct CatchRecordReferenceGenerator: Sendable {
    /// Errors generating a reference. Typed rather than returning `nil`/an empty string, so a
    /// caller can distinguish "no RSS number captured yet" from a successful result (see
    /// swift-swiftui.instructions.md's "no force operations" rule).
    enum GenerationError: Error, Sendable, Equatable {
        /// The vessel's RSS number was empty, or contained characters other than `A–Z`/`0–9`
        /// (after uppercasing) — the service's own `catchRecordReference` shape only ever allows
        /// that character set for the non-fixed segments (see the file-level warning above).
        case invalidRSSNumber(String)
    }

    /// Fixed Gregorian/POSIX calendar so the date/time components below are computed the same way
    /// regardless of the user's own calendar/locale preference (e.g. a non-Gregorian calendar
    /// selected in iOS Settings) — matches the reference-data connector's own `.iso8601` wire-date
    /// convention of never depending on locale/calendar state.
    private static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US_POSIX")
        // UK time: fishers read trip/catch times on local UK clocks (GMT/BST), not UTC — see
        // ADR-0026 "Time zone".
        calendar.timeZone = TimeZone(identifier: "Europe/London") ?? TimeZone(secondsFromGMT: 0)!
        return calendar
    }()

    /// Supplies "now" — injected so tests are deterministic (mirrors `TripDateViewModel`'s own
    /// `now: () -> Date` seam) rather than depending on the wall clock.
    private let now: () -> Date

    init(now: @escaping () -> Date = Date.init) {
        self.now = now
    }

    /// Generates `{RSS}-{DDMMYYYY}-{HHMMSS}` for `rssNumber` at the current instant (`now()`).
    ///
    /// - Parameter rssNumber: The vessel's RSS/registration number (see `VesselOption.rssNumber`).
    ///   Uppercased before validation/use, so a lowercase source value is accepted.
    /// - Throws: `GenerationError.invalidRSSNumber` if, once trimmed and uppercased, `rssNumber` is
    ///   empty or contains any character outside `A–Z0–9`.
    /// - Returns: The generated reference, e.g. `"A12345-27072026-150815"`.
    func generate(rssNumber: String) throws -> String {
        let normalised = rssNumber.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard Self.isValidRSSNumber(normalised) else {
            throw GenerationError.invalidRSSNumber(rssNumber)
        }

        let components = Self.calendar.dateComponents(
            [.day, .month, .year, .hour, .minute, .second],
            from: now()
        )
        guard
            let day = components.day,
            let month = components.month,
            let year = components.year,
            let hour = components.hour,
            let minute = components.minute,
            let second = components.second
        else {
            // Practically unreachable — `Calendar.dateComponents` always populates every
            // requested component for a valid `Date` — but handled explicitly rather than force-
            // unwrapped (no force operations in production code).
            throw GenerationError.invalidRSSNumber(rssNumber)
        }

        let datePart = String(format: "%02d%02d%04d", day, month, year)
        let timePart = String(format: "%02d%02d%02d", hour, minute, second)
        return "\(normalised)-\(datePart)-\(timePart)"
    }

    /// Non-empty, `A–Z`/`0–9` only (after uppercasing) — the only shape this generator ever
    /// produces for the RSS segment of a reference.
    static func isValidRSSNumber(_ value: String) -> Bool {
        !value.isEmpty && value.allSatisfy { $0.isASCII && ($0.isNumber || ($0.isLetter && $0.isUppercase)) }
    }
}
