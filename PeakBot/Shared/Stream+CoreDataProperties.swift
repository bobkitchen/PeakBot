//
//  Stream+CoreDataProperties.swift
//  PeakBot
//
//  Properties and helpers for Stream.
//

import Foundation
import CoreData

extension Stream {
    // Archive/unarchive helpers for [Double]
    public var doubleArray: [Double]? {
        get {
            try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(values) as? [Double]
        }
        set {
            if let arr = newValue {
                values = try! NSKeyedArchiver.archivedData(withRootObject: arr, requiringSecureCoding: false)
            }
        }
    }
}
