//
//  DailyLoad+CoreDataProperties.swift
//  PeakBot
//
//  Properties and helpers for DailyLoad.
//

import Foundation
import CoreData

extension DailyLoad {
    // Add computed properties or helpers as needed.

    static func from(point: FitnessPoint, context: NSManagedObjectContext) -> DailyLoad {
        let d = DailyLoad(context: context)
        d.date = point.date
        d.ctl = point.ctl
        d.atl = point.atl
        d.tsb = point.tsb
        d.tss = 0 // Optionally: sum TSS for this date if needed
        return d
    }
}
