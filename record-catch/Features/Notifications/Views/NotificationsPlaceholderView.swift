//
//  NotificationsPlaceholderView.swift
//  record-catch
//
//  Accessible "coming soon" placeholder for the Notifications tab (see ADR-0006).
//  Full Notifications content is out of scope for this phase — no networking,
//  persistence or real notification data.
//

import SwiftUI

struct NotificationsPlaceholderView: View {

    @Environment(AppLanguageStore.self) private var languageStore

    var body: some View {
        ViewTemplate(title: languageStore.localized("notifications.title")) {
            content
                .environment(\.locale, languageStore.language.locale)
        }
    }

    @ViewBuilder
    private var content: some View {
        // ViewTemplate already renders the localised title as the page heading
        // (with `.isHeader`), so only the supporting paragraph is needed here.
        ParagraphText(text: languageStore.localized("notifications.comingSoon.body"))
    }
}

#Preview("English") {
    NotificationsPlaceholderView()
        .environment(AppLanguageStore.preview)
}

#Preview("Welsh") {
    NotificationsPlaceholderView()
        .environment({
            let store = AppLanguageStore.preview
            store.language = .welsh
            return store
        }())
}

#Preview("Max Dynamic Type") {
    NotificationsPlaceholderView()
        .environment(AppLanguageStore.preview)
        .environment(\.dynamicTypeSize, .accessibility5)
}
