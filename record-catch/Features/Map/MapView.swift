//
//  MapView.swift
//  record-catch
//
//  Created by Paul Halpin on 09/07/2026.
//

import SwiftUI



struct MapView: View {
    @State private var selectedSubzone: String?
    var body: some View {
        ViewTemplate(title: "Map") {
            SeaMapView(selectedSubzone: $selectedSubzone)
                .aspectRatio(1, contentMode: .fit)
                .ignoresSafeArea()
            Text("Subzone: \(selectedSubzone ?? "none")")
            Spacer()
        }
            
    }
}

#Preview {
    MapView()
}
