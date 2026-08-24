//
//  ViewFooter.swift
//  record-catch
//
//  Created by Paul Halpin on 09/07/2026.
//

import SwiftUI

struct ViewFooter: View {
    var body: some View {
        Image("CrownLogoGrey")
            .resizable()
            .scaledToFit()
            .frame(height: 64)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, AppSpacing.large)
            .accessibilityHidden(true)
    }
}

#Preview {
    ViewFooter()
        .environment(AppLanguageStore.preview)
}
