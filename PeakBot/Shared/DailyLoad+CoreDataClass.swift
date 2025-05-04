//
//  DailyLoad+CoreDataClass.swift
//  PeakBot
//
//  NSManagedObject subclass for DailyLoad entity.
//

import Foundation
import CoreData

@objc(DailyLoad)
public class DailyLoad: NSManagedObject, Identifiable {
    @NSManaged public var date: Date
    @NSManaged public var tss: Double
    @NSManaged public var atl: Double
    @NSManaged public var ctl: Double
    @NSManaged public var tsb: Double
}
