//
//  CoreDataModelBuilder.swift
//  PeakBot
//
//  Programmatically defines the entire Core Data model for PeakBot.
//  NOTE: Future schema changes require manual lightweight migration flag
//        (NSMigratePersistentStoresAutomaticallyOption).
//

import Foundation
import CoreData

public enum PeakBotModel {
    public static func build() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()
        // Entities
        let workout = NSEntityDescription()
        workout.name = "Workout"
        workout.managedObjectClassName = "Workout"

        let stream = NSEntityDescription()
        stream.name = "Stream"
        stream.managedObjectClassName = "Stream"

        let dailyLoad = NSEntityDescription()
        dailyLoad.name = "DailyLoad"
        dailyLoad.managedObjectClassName = "DailyLoad"

        let settings = NSEntityDescription()
        settings.name = "Settings"
        settings.managedObjectClassName = "Settings"

        // Workout attributes
        workout.properties = [
            makeInt64("workoutId", indexed: true),
            makeString("name", optional: true),
            makeString("sport"),
            makeDate("startDate"),
            makeDouble("distance", optional: true),
            makeInt64("movingTime"),
            makeDouble("avgPower", optional: true),
            makeDouble("avgHR", optional: true),
            makeDouble("np", optional: true),
            makeDouble("intensityFactor", optional: true),
            makeDouble("tss", optional: true)
        ]

        // Stream attributes
        let streamWorkoutRel = NSRelationshipDescription()
        streamWorkoutRel.name = "workout"
        streamWorkoutRel.destinationEntity = workout
        streamWorkoutRel.minCount = 1
        streamWorkoutRel.maxCount = 1
        streamWorkoutRel.deleteRule = .cascadeDeleteRule
        streamWorkoutRel.isOptional = false

        stream.properties = [
            makeUUID("id", indexed: true),
            makeString("type"),
            makeBinary("values"),
            makeInt64("workoutId"),
            streamWorkoutRel
        ]

        // DailyLoad attributes
        dailyLoad.properties = [
            makeDate("date", indexed: true),
            makeDouble("tss"),
            makeDouble("atl"),
            makeDouble("ctl"),
            makeDouble("tsb")
        ]

        // Settings attributes
        settings.properties = [
            makeUUID("id", indexed: true),
            makeDouble("ftp", defaultValue: 250.0),
            makeBinary("hrZones", optional: true),
            makeDate("lastSync", optional: true)
        ]

        model.entities = [workout, stream, dailyLoad, settings]
        // model.preservesPendingChanges = true

        return model
    }

    private static func makeInt64(_ name: String, indexed: Bool = false, optional: Bool = false) -> NSAttributeDescription {
        let attr = NSAttributeDescription()
        attr.name = name
        attr.attributeType = .integer64AttributeType
        attr.isOptional = optional
        attr.isIndexed = indexed
        return attr
    }

    private static func makeDouble(_ name: String, optional: Bool = false, defaultValue: Double? = nil) -> NSAttributeDescription {
        let attr = NSAttributeDescription()
        attr.name = name
        attr.attributeType = .doubleAttributeType
        attr.isOptional = optional
        if let val = defaultValue { attr.defaultValue = val }
        return attr
    }

    private static func makeString(_ name: String, optional: Bool = false) -> NSAttributeDescription {
        let attr = NSAttributeDescription()
        attr.name = name
        attr.attributeType = .stringAttributeType
        attr.isOptional = optional
        return attr
    }

    private static func makeDate(_ name: String, indexed: Bool = false, optional: Bool = false) -> NSAttributeDescription {
        let attr = NSAttributeDescription()
        attr.name = name
        attr.attributeType = .dateAttributeType
        attr.isOptional = optional
        attr.isIndexed = indexed
        return attr
    }

    private static func makeUUID(_ name: String, indexed: Bool = false, optional: Bool = false) -> NSAttributeDescription {
        let attr = NSAttributeDescription()
        attr.name = name
        attr.attributeType = .UUIDAttributeType
        attr.isOptional = optional
        attr.isIndexed = indexed
        return attr
    }

    private static func makeBinary(_ name: String, optional: Bool = false) -> NSAttributeDescription {
        let attr = NSAttributeDescription()
        attr.name = name
        attr.attributeType = .binaryDataAttributeType
        attr.isOptional = optional
        return attr
    }
}
