//
//  Settings+CoreDataClass.swift
//  PeakBot
//
//  NSManagedObject subclass for Settings entity.
//

import Foundation
import CoreData

@objc(Settings)
public class Settings: NSManagedObject, Identifiable {
    @NSManaged public var id: UUID
    @NSManaged public var ftp: Double
    @NSManaged public var hrZones: Data?
    @NSManaged public var lastSync: Date?
}
