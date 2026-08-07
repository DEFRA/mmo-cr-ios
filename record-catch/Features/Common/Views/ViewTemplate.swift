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
            .background(AppColors.background)
        }
        .background(AppColors.background)
    }
}

#Preview {
    ViewTemplate(title: "Test") {
        Text("Test")
    }
    .environment(AppLanguageStore.preview)
}
