//
//  Item.swift
//  record-catch
//
//  Created by Paul Halpin on 08/07/2026.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
