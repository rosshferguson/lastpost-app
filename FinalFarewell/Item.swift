//
//  Item.swift
//  FinalFarewell
//
//  Created by Ross Ferguson on 27/06/2026.
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
