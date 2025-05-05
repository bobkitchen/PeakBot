//
//  FTPHistoryManager.swift
//  PeakBot
//
//  Helper for managing FTP history and lookup.
//

import Foundation
import CoreData

class FTPHistoryManager {
    static let shared = FTPHistoryManager()
    private init() {}

    // Returns the FTP in effect for a given date
    func ftp(for date: Date, context: NSManagedObjectContext) -> Double? {
        let request = NSFetchRequest<FTPHistory>(entityName: "FTPHistory")
        request.predicate = NSPredicate(format: "date <= %@", date as NSDate)
        request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
        request.fetchLimit = 1
        do {
            let results = try context.fetch(request)
            return results.first?.ftp
        } catch {
            print("[FTPHistoryManager] Error fetching FTP for date: \(error)")
            return nil
        }
    }

    // Add new FTP entry
    func addFTP(_ ftp: Double, effective date: Date = Date(), context: NSManagedObjectContext) {
        let entry = FTPHistory(context: context)
        entry.id = UUID()
        entry.date = date
        entry.ftp = ftp
        do {
            try context.save()
            print("[FTPHistoryManager] Added FTP entry: \(ftp) @ \(date)")
        } catch {
            print("[FTPHistoryManager] Error saving FTP entry: \(error)")
        }
    }

    // Fetch all FTP history entries, sorted
    func allHistory(context: NSManagedObjectContext) -> [FTPHistory] {
        let request = NSFetchRequest<FTPHistory>(entityName: "FTPHistory")
        request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
        do {
            return try context.fetch(request)
        } catch {
            print("[FTPHistoryManager] Error fetching all FTP history: \(error)")
            return []
        }
    }
}
