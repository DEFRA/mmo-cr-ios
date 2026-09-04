//
//  LaunchArguments.swift
//  record-catch
//
//  Centralises the `-uiTest*` launch-argument flags used to seed deterministic app state for
//  XCUITest hosting (see ADR-0006/ADR-0009). Named, typed flags replace scattered
//  `ProcessInfo.processInfo.arguments.contains("-uiTest...")` string literals, so a typo becomes a
//  compile error instead of a silently-never-matching UI-test seam.
//

import Foundation

/// Thin, testable wrapper around the process's launch arguments.
struct LaunchArguments {
    /// Named `-uiTest*` seams recognised across the app entry point. Grouped by the area of the
    /// app they seed.
    enum Flag: String {
        // Root session / app-lock (ADR-0009)
        case appLockLocked = "-uiTestAppLockLocked"
        case appLockFallback = "-uiTestAppLockFallback"

        // Tab / feature hosting
        case home = "-uiTestHome"
        case settings = "-uiTestSettings"
        case manageAccount = "-uiTestManageAccount"
        case notifications = "-uiTestNotifications"
        case tabBar = "-uiTestTabBar"

        // Catch record journey (ADR-0006)
        case catchRecordDraft = "-uiTestCatchRecordDraft"
        case catchRecordNew = "-uiTestCatchRecordNew"
        case catchRecordAddPort = "-uiTestCatchRecordAddPort"
        case catchRecordSelectPort = "-uiTestCatchRecordSelectPort"
        case catchRecordSelectGear = "-uiTestCatchRecordSelectGear"
        case catchRecordCheckYourAnswers = "-uiTestCatchRecordCheckYourAnswers"
        case catchRecordSubmissionConfirmation = "-uiTestCatchRecordSubmissionConfirmation"
        case catchRecordSubmissionSuccess = "-uiTestCatchRecordSubmissionSuccess"
    }

    /// The live process's launch arguments, read once per `LaunchArguments` value.
    static var current: LaunchArguments { LaunchArguments() }

    private let raw: Set<String>

    init(raw: [String] = ProcessInfo.processInfo.arguments) {
        self.raw = Set(raw)
    }

    func contains(_ flag: Flag) -> Bool {
        raw.contains(flag.rawValue)
    }
}
