<!-- PackList CLAUDE.md v1.0 — Last updated: May 2026 -->
# PackList — Claude Code Standards & Project Context

## Project overview
Native iOS app (Swift, SwiftUI, SwiftData, iOS 17+) for intelligent travel packing lists. Solo developer project for personal use. Owned by Jason Gray.

## Architecture
- Pattern: MVVM + Repository abstraction
- Persistence: SwiftData (v1) — all data access via repository protocols only, never access ModelContext directly outside repositories
- Sync: local-first, sync backend TBD — never couple UI or business logic to a specific backend
- Checklist engine: pure struct, no SwiftData imports, no side effects — takes TripSession + [MasterItem], returns [TripItem]
- AI is non-blocking and non-required — the app must function fully without any AI calls

## Code standards
- Swift 5.9+, @Observable macro for ViewModels (not ObservableObject)
- All repository operations must run on @MainActor
- No force unwraps — use guard let, if let, or provide safe defaults
- No print statements in committed code — use os.log or remove before committing
- Errors must be surfaced to the user — never silently swallow a catch block
- No hardcoded strings visible to the user — use constants or localization keys

## Naming conventions
- ViewModels: [Feature]ViewModel.swift
- Views: [Feature]View.swift
- Repositories: SwiftData[Entity]Repository.swift implementing [Entity]Repository protocol
- Services: [Name]Service.swift
- Tests: [Target]Tests.swift

## Git workflow
- Branch naming: feature/issue-[number]-short-description or fix/issue-[number]-short-description
- Every commit must reference an issue number: "Fix duplicate items in trip list (#1)"
- Always push after committing: git push origin [branch]
- Open a PR for every feature or fix — never commit directly to main
- PR titles must match the issue title

## Testing standards per PR

Every PR must:
- Pass all existing tests
- Add tests for any new repository methods
- Add tests for any new ChecklistEngine logic  
- Add tests for any new service methods
- Add tests for any new @Model fields or relationships
- Never reduce total test count
- Never reduce code coverage percentage

Coverage targets by layer:
- Services (ChecklistEngine, ImportService): 90%+
- Repositories: 80%+
- ViewModels: 60%+
- Models: 70%+
- Views: exempt

Before opening any PR, run the full test suite with coverage:
```
xcodebuild test -scheme PackList \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -enableCodeCoverage YES \
  -resultBundlePath /tmp/PackListTestResults.xcresult
```

Then check coverage:
```
xcrun xccov view --report /tmp/PackListTestResults.xcresult | grep -E "(PackList/|TOTAL)"
```

If any tracked layer is below its target, or if coverage drops from the previous run, add tests before opening the PR. Never open a PR that reduces coverage.

If you are unsure what tests to add, run:
```
xcrun xccov view --report /tmp/PackListTestResults.xcresult --json | python3 -c "
import json,sys
data=json.load(sys.stdin)
for f in data.get('targets',[{}])[0].get('files',[]):
    cov=f['lineCoverage']
    if cov < 0.7:
        print(f\"{cov:.0%} {f['name']}\")
" 2>/dev/null || echo "Check coverage report manually"
```

Then write tests for any file below 70%.

## SwiftUI / HIG standards
- Follow Apple Human Interface Guidelines strictly
- Minimum tap target: 44x44pt
- Support Dynamic Type — never hardcode font sizes
- No custom navigation patterns — use NavigationStack and sheet/fullScreenCover
- Animations: keep subtle, use .animation(.easeInOut(duration: 0.2)) as default

## Project structure
```
PackList/
├── Models/           # SwiftData @Model classes and supporting structs
├── Repositories/
│   ├── Protocols/    # Repository protocols — no SwiftData imports here
│   └── SwiftData*Repository.swift files
├── Services/         # ChecklistEngine, ImportService, etc.
├── ViewModels/       # @Observable ViewModels
├── Views/            # SwiftUI views only, no business logic
│   ├── Home/
│   ├── Trip/
│   ├── Packing/
│   ├── Tasks/
│   ├── MasterList/
│   └── Suggestions/
├── Resources/
│   └── SeedData/     # master_items.json
└── Tests/
```

## Key data model decisions
- TripItem.completedAt: Date? replaces isChecked: Bool — nil means incomplete
- MasterItem.requiredByItemId: UUID? — dependency chain for accessories
- TripSession.parentTripId: UUID? — self-referencing FK for trip cloning
- ItemInsight — materialized aggregate per (MasterItem × TripPurpose × Region) — never query raw TripItem history in the UI layer
- flightAccessible: Bool is a dedicated field, not a tag — drives flight prep view

## Current milestone
v0.1 Alpha — Daily Driver. See GitHub Issues for backlog: https://github.com/jasonegray/projects/1

## Things Jason cares about
- Clean, minimal, Apple-quality UI — if it doesn't feel native, redo it
- No debug code in commits
- Every PR should be reviewable — small, focused, one thing at a time
- The master list is sacred — nothing changes it without explicit user approval
- Performance matters — the packing list must feel instant, no loading spinners on local data

---

## How Claude Code should behave

### Session start template

When Jason says "start a coding session", follow these steps:

0. Run test-audit and include the report in the session plan:
   Run: `test-audit`
   Include the TESTFLIGHT READINESS, COVERAGE summary, and READY FOR NEXT SESSION sections in the session plan output. If any file is below its coverage target, flag it in the session plan so Jason can decide whether to address it before new features.

1. Backlog analysis: review open GitHub issues and the project board, identify the highest-priority unblocked items, and propose a session plan.

### Before coding
Before implementing any change:
1. Inspect all relevant files that will be touched
2. Summarize the intended change and which files will be modified
3. Wait for confirmation if the change touches models, repositories, seed data, or core services
4. Never introduce a new architectural pattern without explicit approval from Jason

### Destructive change protocol
Always ask before:
- Modifying SwiftData @Model classes (requires migration planning)
- Changing or regenerating master_items.json
- Deleting any file from the project
- Changing repository protocol signatures
- Modifying ChecklistEngine logic that has passing tests
- Any change that would invalidate existing persisted data

State clearly: "This change is destructive — [what it affects]. Confirm before I proceed?"

### SwiftData schema change protocol

Any change to a `@Model` class is a DESTRUCTIVE CHANGE requiring explicit approval:
- Adding a field to a `@Model` class
- Removing a field from a `@Model` class
- Renaming a field on a `@Model` class
- Moving a `@Model` class into a namespace, enum, or nested type
- Adding a new `@Model` class
- Changing a `@Relationship` rule

Before making any of the above changes, output:
`NEEDS JASON: SwiftData schema change — [describe exactly what is changing and the migration risk]`
Then stop and wait for explicit confirmation.

Never wrap `@Model` classes inside enums, structs, or other types for any reason — this changes the fully qualified type name and breaks SwiftData's entity registry silently.

Every PR that touches a `@Model` file must confirm:
- [ ] Entity class names are unchanged (no nesting, no renaming)
- [ ] New fields are `Optional` or have default values
- [ ] `testInsertAndFetchRoundTrip()` passes
- [ ] If migration is needed, a `VersionedSchema` + `MigrationStage` is in place AND tested

### UI design requirement

Any issue that creates a new screen or significantly modifies an existing screen must have a DESIGN section in the issue body before a terminal begins view code.

If assigned a UI issue with no DESIGN section in the body, output:
`NEEDS JASON: no UI design specified for this screen — add a DESIGN section to issue #[N] before proceeding`
Then stop and wait.

A DESIGN section must include at minimum:
- Screen name and entry point
- List of sections and fields in order
- Any fields that are pre-filled from other data sources
- What the primary action is
- Any fields explicitly excluded

### XCUITest requirement

Any PR that creates a new screen or significantly modifies an existing screen must include XCUITest coverage for that screen in the same PR.

Minimum required for each new screen:
- One test that navigates to the screen and asserts it loads without crash
- One test that exercises the primary action on the screen

If writing XCUITest for the screen is not possible (e.g. requires complex state setup), output:
`NEEDS JASON: XCUITest not written for [screen name] — [reason]`
Then proceed with the PR but flag it for follow-up.

XCUITest file: PackList/UITests/PackListUITests.swift
Use XCUIApplication() — never hardcode element strings, use accessibility identifiers where possible.

### PR checklist
Every PR must include confirmation that all of the following pass before opening:

**Code quality**
- [ ] No force unwraps (!) anywhere in changed files
- [ ] No print() statements — use os.log or remove
- [ ] No TODO or FIXME comments left in — resolve or create a GitHub issue
- [ ] No hardcoded user-facing strings

**Architecture**
- [ ] No direct ModelContext access outside of SwiftData*Repository files
- [ ] No business logic in Views
- [ ] No SwiftData imports in Services or ViewModels
- [ ] Repository protocols unchanged unless explicitly approved

**Testing**
- [ ] All existing tests pass (run test suite before opening PR)
- [ ] New repository methods have at least one test
- [ ] ChecklistEngine changes have corresponding test coverage

**Error handling**
- [ ] No silent catch blocks — errors are logged or surfaced to user
- [ ] Network failures handled gracefully
- [ ] Nil cases handled — no assumptions about optional values

**UI / HIG**
- [ ] Tap targets minimum 44x44pt
- [ ] No hardcoded font sizes — use Dynamic Type styles
- [ ] Follows NavigationStack / sheet patterns — no custom navigation hacks
- [ ] Tested in both light and dark mode
- [ ] Animations are subtle — default to .easeInOut(duration: 0.2)

**Git**
- [ ] Branch named: feature/issue-[number]-description or fix/issue-[number]-description
- [ ] Commit messages reference issue number
- [ ] No merge commits on the branch — rebase if needed
- [ ] PR title matches the GitHub issue title exactly

### Communication style
- Be explicit about what you are about to do before doing it
- If something is ambiguous, ask — do not assume
- If a simpler solution exists, propose it before implementing the complex one
- Flag anything that looks like technical debt, even if not in scope
- One PR per issue — do not bundle unrelated changes

---

## Project board workflow — mandatory for every issue

### Adding issues to the board (mandatory)
Every issue created — whether via capture-issue skill, manual `gh issue create`, or any other method — must be immediately added to the project board and placed in the Backlog column. This is mandatory, not optional.

After every `gh issue create` command, always run:
```
gh project item-add 1 --owner jasonegray --url https://github.com/jasonegray/travel/issues/[N]
```
Then move to Backlog via GraphQL:
```
gh api graphql -f query='mutation { updateProjectV2ItemFieldValue(input: { projectId: "PVT_kwHOEMO09M4BWtlG" itemId: "[ITEM_ID]" fieldId: "PVTSSF_lAHOEMO09M4BWtlGzhR_g7M" value: { singleSelectOptionId: "ca2d7b25" } }) { projectV2Item { id } } }'
```

Never report an issue as created without confirming it is on the board in Backlog.

**When starting work on an issue:**
- Move the issue to In Progress on the project board
- Apply the correct terminal label (T1, T2, T3, T4)

**When opening a PR:**
- Ensure the issue is In Progress on the board
- PR description must include "Closes #[issue number]"

**When a PR is merged:**
- Issue automatically closes if "Closes #N" is in PR description
- If it does not auto-close, manually close and move to Done
- Remove the terminal label

Never leave an issue in Backlog while actively working on it. Never leave a merged PR with its issue still open.
