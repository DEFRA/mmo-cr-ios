//
//  MapView.swift
//  record-catch
//
//  Created by Paul Halpin on 09/07/2026.
//

import MapKit
import SwiftUI

struct MapView: View {
    @State private var selectedSubrectangle: SubrectangleProperties?

    var body: some View {
        ViewTemplate(title: "Map") {
            OfflineMapView(
                initialCoordinate: CLLocationCoordinate2D(latitude: 55.0, longitude: -3.5),
                initialSpan: MKCoordinateSpan(latitudeDelta: 12.0, longitudeDelta: 8.0),
                selectedSubrectangle: $selectedSubrectangle
            )
            .aspectRatio(1, contentMode: .fit)
            .ignoresSafeArea()
            Text("Subrectangle: \(selectedSubrectangle?.subCode ?? "none")")
            Spacer()
        }
    }
}


#Preview {
    MapView()
}
