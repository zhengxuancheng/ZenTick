//
//  Item.swift
//  ZenTick
//
//  Created by 刘金星 on 2026/4/14.
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
