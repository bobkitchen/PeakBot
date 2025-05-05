//
//  Workout+CoreDataClass.swift
//  PeakBot
//
//  NSManagedObject subclass for Workout entity.
//

import Foundation
import CoreData

@objc(Workout)
public class Workout: NSManagedObject, Identifiable {
    @NSManaged public var workoutId: NSNumber?
    @NSManaged public var name: String?
    @NSManaged public var sport: String?
    @NSManaged public var startDate: Date?
    @NSManaged public var distance: NSNumber?
    @NSManaged public var movingTime: NSNumber?
    @NSManaged public var avgPower: NSNumber?
    @NSManaged public var avgHR: NSNumber?
    @NSManaged public var np: NSNumber?
    @NSManaged public var intensityFactor: NSNumber?
    @NSManaged public var tss: NSNumber?
    @NSManaged public var ftpUsed: Double
}
