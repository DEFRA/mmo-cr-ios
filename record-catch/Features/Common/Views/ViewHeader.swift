//
//  ViewHeader.swift
//  record-catch
//
//  Created by Paul Halpin on 09/07/2026.
//

import SwiftUI

struct ViewHeader: View {
    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color.blue)
                .frame(height: 50)
            HStack{
                Text("GOV.UK")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                Spacer()
            }
            .padding()
            .backgroundStyle(.black)
        }
    }
}

#Preview {
    ViewHeader()
}
