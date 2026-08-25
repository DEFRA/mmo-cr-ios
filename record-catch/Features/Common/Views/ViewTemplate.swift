//
//  ViewTemplate.swift
//  record-catch
//
//  Created by Paul Halpin on 09/07/2026.
//

import SwiftUI

struct ViewTemplate<Content: View>: View {

    let title: String
    /// Optional important-information box rendered at the very top of the
    /// content, above the page title. Opt-in per screen (defaults to `nil`) so
    /// existing screens are unaffected.
    let warning: WarningBox?
    let content: Content

    init(
        title: String,
        warning: WarningBox? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.warning = warning
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            ViewHeader()
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: AppSpacing.large) {
                        if let warning {
                            warning
                        }
                        // Render the page title only when non-empty, so a screen can
                        // opt out (e.g. when it renders its own heading) without a
                        // blank heading slot appearing.
                        if !title.isEmpty {
                            TitleText(text: title)
                                .accessibilityAddTraits(.isHeader)
                        }
                        content
                        ViewFooter()
                    }
                    .padding(.horizontal, AppSpacing.medium)
                    .padding(.vertical, AppSpacing.large)
                }
                .environment(\.scrollViewProxy, proxy)
                .background(AppColors.background)
            }
        }
        .background(AppColors.background)
        // The custom `ViewHeader` is the single source of truth for back
        // navigation and branding, so hide the system navigation bar to avoid a
        // duplicate back chevron rendered on top of the custom header.
        //
        // NOTE: We hide the bar via `.toolbar(.hidden:)` only — we deliberately
        // do NOT add `.navigationBarBackButtonHidden(true)`. Hiding the toolbar
        // removes the duplicate chevron while preserving the interactive
        // swipe-from-edge back gesture, which `NavigationStack` reflects into the
        // bound router `path` (see `CatchRecordRouter.setPath`). Disabling the
        // back button would kill that gesture, so it stays enabled.
        .toolbar(.hidden, for: .navigationBar)
    }
}

#Preview {
    ViewTemplate(title: "Test") {
        Text("Test")
    }
    .environment(AppLanguageStore.preview)
}
