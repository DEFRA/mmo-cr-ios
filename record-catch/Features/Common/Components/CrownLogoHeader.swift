//
//  CrownLogoHeader.swift
//  record-catch
//
//  The DEFRA crown logo, centred, used atop the plain auth-style screens (Sign In, password
//  reset journey — ADR-0027). Purely decorative, so hidden from VoiceOver/Switch Control.
//
//  Extracted to remove the duplicated image block repeated across the password-reset screens.
//

import SwiftUI

struct CrownLogoHeader: View {
    var body: some View {
        Image("CrownLogo")
            .resizable()
            .scaledToFit()
            .frame(width: 64, height: 64)
            .frame(maxWidth: .infinity, alignment: .center)
            .accessibilityHidden(true)
    }
}

#Preview {
    CrownLogoHeader()
}
