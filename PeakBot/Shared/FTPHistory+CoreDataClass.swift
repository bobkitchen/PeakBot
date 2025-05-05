//
//  FTPHistory+CoreDataClass.swift
//  PeakBot
//
//  NSManagedObject subclass for FTPHistory entity.
//

import Foundation
import CoreData

@objc(FTPHistory)
public class FTPHistory: NSManagedObject, Identifiable {
    @NSManaged public var date: Date
    @NSManaged public var ftp: Double
    @NSManaged public var id: UUID
}
