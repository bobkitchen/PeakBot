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
            guard let data = values else { return nil }
            return try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data) as? [Double]
        }
        set {
            if let arr = newValue {
                values = try! NSKeyedArchiver.archivedData(withRootObject: arr, requiringSecureCoding: false)
            }
        }
    }
    
    var decodedValues: [Double] {
        guard let data = values else { return [] }
        return (try? JSONDecoder().decode([Double].self, from: data)) ?? []
    }
}
