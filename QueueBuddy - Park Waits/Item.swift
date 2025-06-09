//
//  Item.swift
//  QueueBuddy - Park Waits
//
//  Created by Robby Dzielinski on 6/9/25.
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
