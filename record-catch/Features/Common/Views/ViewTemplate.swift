//
//  ViewTemplate.swift
//  record-catch
//
//  Created by Paul Halpin on 09/07/2026.
//

import SwiftUI

struct ViewTemplate<Content: View>: View {
    
    
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(spacing: 0) {
            ViewHeader()
            ScrollView {
                content
                ViewFooter()
            }
        }
    }
    
}

#Preview {
    ViewTemplate(title: "Test") {
        Text("Test")
    }
}
