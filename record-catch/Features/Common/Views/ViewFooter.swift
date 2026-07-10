//
//  ViewFooter.swift
//  record-catch
//
//  Created by Paul Halpin on 09/07/2026.
//

import SwiftUI

struct ViewFooter: View {
    var body: some View {
            Divider()

            VStack(alignment: .leading, spacing: 8) {

                Text("Support")
                    .font(.headline)

                Link(
                    "Contact Defra",
                    destination: URL(string: "https://www.gov.uk")!
                )

                Text("© Crown copyright")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(.top)
        }

}

#Preview {
    ViewFooter()
}
