import SwiftData

// How to add a new schema version:
//  1. Create PackListSchemaV2.swift with updated @Model classes inside the enum.
//  2. Add a MigrationStage below (lightweight or custom as needed).
//  3. Append PackListSchemaV2.self to `schemas`.
//  4. Update the top-level typealias in the affected model file to point to V2.
enum PackListMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [PackListSchemaV1.self]
    }

    static var stages: [MigrationStage] {
        []
    }
}
