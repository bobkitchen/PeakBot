// CoreDataModel.swift
// PeakBot
//
// Defines Core Data stack and entities for Strava integration.
//

import Foundation
import CoreData

@MainActor
final class CoreDataModel: ObservableObject {
    static let shared = CoreDataModel()

    let container: NSPersistentContainer

    private init(inMemory: Bool = false) {
        let model = PeakBotModel.build()
        container = NSPersistentContainer(name: "PeakBot", managedObjectModel: model)
        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }
        container.loadPersistentStores { desc, error in
            if let error = error {
                fatalError("Failed to load Core Data store: \(error)")
            }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
    }
}

// MARK: - Entities

extension CoreDataModel {
    // Workout entity
    static func makeWorkout(context: NSManagedObjectContext) -> Workout {
        let w = Workout(context: context)
        w.workoutId = nil
        w.name = nil
        w.sport = nil
        w.startDate = nil
        w.distance = nil
        w.movingTime = nil
        w.avgPower = nil
        w.avgHR = nil
        w.np = nil
        w.intensityFactor = nil
        w.tss = nil
        return w
    }
    // DailyLoad entity
    static func makeDailyLoad(context: NSManagedObjectContext) -> DailyLoad {
        let d = DailyLoad(context: context)
        d.date = Date()
        d.tss = 0
        d.atl = 0
        d.ctl = 0
        d.tsb = 0
        return d
    }
    // Add similar factory methods for Stream, Settings as needed.
}

// All NSManagedObject subclass declarations have been removed from this file.
