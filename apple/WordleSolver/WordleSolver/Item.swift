//
//  Item.swift
//  WordleSolver
//
//  Created by Jeremy Felix on 2026-06-17.
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
