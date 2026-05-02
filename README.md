# PackList

A native iOS packing list app built with SwiftUI and SwiftData. PackList helps you build and manage trip-specific packing lists based on your destination, activities, travel companions, and weather — with an optional AI layer for suggestions that always requires explicit approval before changing anything.

## Requirements

- Xcode 16+ (project targets iOS 17)
- iOS 17.0 minimum deployment target
- Swift 5.9+

## Setup

1. Clone the repo:
   ```bash
   git clone https://github.com/jasonegray/travel.git
   cd travel
   ```

2. Generate the Xcode project (requires [xcodegen](https://github.com/yonaskolb/XcodeGen)):
   ```bash
   brew install xcodegen
   xcodegen generate
   ```

3. Open the project:
   ```bash
   open PackList.xcodeproj
   ```

4. Select your development team in **Signing & Capabilities** and run on a simulator or device.

## Project Structure

```
PackList/
├── project.yml                  # xcodegen project spec
├── PackList/
│   ├── PackListApp.swift        # App entry point + SwiftData model container
│   ├── Models/
│   │   ├── TripSession.swift    # Core trip entity
│   │   ├── MasterItem.swift     # Canonical item definitions
│   │   ├── TripItem.swift       # Per-trip item instances
│   │   ├── ItemInsight.swift    # Usage analytics per item/context
│   │   ├── PendingSuggestion.swift  # AI suggestion queue (human-approved)
│   │   ├── Enums.swift          # All shared enumerations
│   │   └── Supporting/
│   │       ├── QuantityRule.swift
│   │       └── ReplaceabilityRule.swift
│   ├── Repositories/
│   │   └── Protocols/           # Data access interfaces (v1: SwiftData)
│   ├── Services/                # Business logic, packing engine
│   ├── ViewModels/              # ObservableObject / @Observable view models
│   ├── Views/                   # SwiftUI views
│   ├── Resources/               # Assets, colors, fonts
│   └── Tests/                   # Unit tests
```

## Architecture

**Repository protocol pattern** — all data access goes through protocols defined in `Repositories/Protocols/`. The v1 implementation uses SwiftData. Swapping the backing store (e.g. CloudKit, a remote API) only requires a new conforming type.

**AI is enhancement only** — the app is fully functional without any AI integration. AI suggestions land in `PendingSuggestion` and require explicit user approval before touching the master item list.

**Human-in-the-loop** — nothing modifies `MasterItem` records without a user action. `PendingSuggestion.status` must transition to `.approved` before any change is applied.

## Data Model

| Model | Purpose |
|---|---|
| `TripSession` | A single trip with destination, dates, activities, and a cascade-deleted item list |
| `MasterItem` | The canonical definition of a packable item, with quantity rules and replaceability rules |
| `TripItem` | A resolved instance of an item on a specific trip |
| `ItemInsight` | Aggregated usage statistics per item/purpose/region, used to improve suggestions |
| `PendingSuggestion` | A proposed change from the AI layer awaiting human approval |

## Regenerating the Xcode Project

The `.xcodeproj` is generated from `project.yml` and is committed for convenience. If you add new source files outside of Xcode, re-run:

```bash
xcodegen generate
```
