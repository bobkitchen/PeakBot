//
//  Settings+CoreDataProperties.swift
//  PeakBot
//
//  Properties and helpers for Settings.
//

import Foundation
import CoreData

extension Settings {
    // Archive/unarchive helpers for [Int: Int]
    public var hrZonesDict: [Int: Int]? {
        get {
            guard let data = hrZones else { return nil }
            return try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data) as? [Int: Int]
        }
        set {
            if let dict = newValue {
                hrZones = try? NSKeyedArchiver.archivedData(withRootObject: dict, requiringSecureCoding: false)
            }
        }
    }
}
