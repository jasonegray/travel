// VersionedSchema removed — wrapping @Model classes inside this enum changed their
// fully qualified type names from PackList.TripSession to
// PackList.PackListSchemaV1.TripSession, causing SwiftData entity registration to
// break: context.fetch() returned 0 immediately after context.insert() + save() on
// the same context. Model classes restored to top-level definitions in Models/*.swift.
// If schema versioning is needed in future, use @Model(originalName:) to preserve
// entity names across renames instead of nesting inside a VersionedSchema enum.
