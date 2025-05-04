//
//  Stream+CoreDataClass.swift
//  PeakBot
//
//  NSManagedObject subclass for Stream entity.
//

import Foundation
import CoreData

@objc(Stream)
public class Stream: NSManagedObject, Identifiable {
    @NSManaged public var id: UUID
    @NSManaged public var type: String
    @NSManaged public var values: Data
    @NSManaged public var workout: Workout
}
