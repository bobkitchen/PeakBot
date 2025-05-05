//
//  FTPHistory+CoreDataProperties.swift
//  PeakBot
//
//  Properties for FTPHistory entity.
//

import Foundation
import CoreData

extension FTPHistory {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<FTPHistory> {
        return NSFetchRequest<FTPHistory>(entityName: "FTPHistory")
    }
}
