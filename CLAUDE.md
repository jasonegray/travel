<!-- PackList CLAUDE.md v1.0 — Last updated: May 2026 -->
# PackList — Claude Code Standards & Project Context

## Project overview
Native iOS app (Swift, SwiftUI, SwiftData, iOS 17+) for intelligent travel packing lists. Solo developer project for personal use. Owned by Jason Gray.

## Session Startup
At the start of every Claude Code session:
1. Read this entire CLAUDE.md before doing anything
2. Run: gh issue list --state open --limit 50 --json number,title,milestone,labels
3. Run: git log --oneline -10
4. Run: git status
5. Report back with: current branch, last 10 commits, open issue count, and any open PRs
6. Wait for Jason's instructions — do not start any work until instructed

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

Do NOT run UITests (XCUITest) as part of any PR workflow. UI tests are managed outside of Claude Code sessions. Only run the unit test suite:

```
xcodebuild test -scheme PackList -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:PackListTests
```

If any existing test fails, fix it before opening the PR. Never reduce the test count.

Write new tests only when:
- The PR touches a Repository or Service (ChecklistEngine, ImportService)
- The PR is explicitly a testing sprint

ViewModels, Views, and UI changes are exempt from new test requirements.
Do not run coverage reports — this is handled separately via test-audit.
Do not write XCUITest unless explicitly assigned as a testing task.

The two mandatory tests that must always pass:
- testInsertAndFetchRoundTrip
- testFullAppLaunchSequence

## TestFlight Deployment

Xcode 26 beta has a known bug where the project editor does not load. Use the CLI workflow exclusively for all TestFlight builds.

### Step 1 — Bump build number
```
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion [N]" PackList/Info.plist
git add PackList/Info.plist && git commit -m "Bump build number to [N]" && git push origin main
```

### Step 2 — Archive
```
xcodebuild -project PackList.xcodeproj -scheme PackList -configuration Release -destination 'generic/platform=iOS' -archivePath /tmp/PackList[N].xcarchive DEVELOPMENT_TEAM=8WXGQKFXC3 CODE_SIGN_STYLE=Automatic archive
```

### Step 3 — Export
Ensure /tmp/ExportOptions.plist exists:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>app-store-connect</string>
    <key>teamID</key>
    <string>8WXGQKFXC3</string>
</dict>
</plist>
```
```
xcodebuild -exportArchive -archivePath /tmp/PackList[N].xcarchive -exportOptionsPlist /tmp/ExportOptions.plist -exportPath /tmp/PackListExport
```

### Step 4 — Upload
```
xcrun altool --upload-app --type ios --file /tmp/PackListExport/PackList.ipa --username jason@level19.com --password APP_SPECIFIC_PASSWORD
```

Note: Generate a fresh app-specific password at appleid.apple.com for each upload. Revoke after use.

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

### Autonomous terminal workflow — Gemini review threshold

8. Assess PR complexity before waiting for Gemini review.

   Skip Gemini (merge immediately when tests pass) for:
   - UI-only changes (no model, repository, or service changes)
   - Single-file changes under 50 lines
   - Polish, label, copy, or icon changes
   - Adding new Optional fields with default values

   Wait for Gemini review for:
   - Any change to a @Model class or repository
   - Any change to ChecklistEngine or ImportService
   - Any change to PackListApp.swift or RepositoryContainer
   - Any PR touching 3+ files with logic changes
   - Any PR estimated medium complexity (5/10) or above

   When waiting for Gemini:
   ```
   gh pr view [PR#] --comments
   ```
   Poll every 2 minutes, max 15 minutes.
   Handle all Gemini comments autonomously.
   If Gemini does not review within 15 minutes, merge anyway.

10. Close issue and move to Done on the project board:
    ```
    gh issue close [N] --comment "Completed in PR #[PR#]."
    ```

    Then explicitly move to Done via GraphQL:
    ```
    gh api graphql -f query='mutation {
      updateProjectV2ItemFieldValue(input: {
        projectId: "PVT_kwHOEMO09M4BWtlG"
        itemId: "PVTI_ITEM_ID"
        fieldId: "PVTSSF_lAHOEMO09M4BWtlGzhR_g7M"
        value: { singleSelectOptionId: "39656e02" }
      }) { projectV2Item { id } }
    }'
    ```

    To get the item ID for the issue:
    ```
    gh api graphql -f query='{ 
      repository(owner: "jasonegray", name: "travel") { 
        issue(number: [N]) { 
          projectItems(first: 1) { 
            nodes { id } 
          } 
        } 
      } 
    }' --jq '.data.repository.issue.projectItems.nodes[0].id'
    ```

---

## Project board workflow — mandatory for every issue

### Adding issues to the board (mandatory)
Every issue created — whether via capture-issue skill, manual `gh issue create`, or any other method — must be immediately added to the project board and placed in the Backlog column. This is mandatory, not optional.

After every `gh issue create` command, always run:
```
gh project item-add 1 --owner jasonegray --url https://github.com/jasonegray/travel/issues/[N]
```

Then immediately get the item ID and set its status to Backlog:
```
gh api graphql -f query='{ repository(owner: "jasonegray", name: "travel") { issue(number: [N]) { projectItems(first: 1) { nodes { id } } } } }' --jq '.data.repository.issue.projectItems.nodes[0].id'
```
```
gh api graphql -f query='mutation {
  updateProjectV2ItemFieldValue(input: {
    projectId: "PVT_kwHOEMO09M4BWtlG"
    itemId: "ITEM_ID_HERE"
    fieldId: "PVTSSF_lAHOEMO09M4BWtlGzhR_g7M"
    value: { singleSelectOptionId: "ca2d7b25" }
  }) { projectV2Item { id } }
}'
```

Every issue must have a status the moment it lands on the board. No issue should ever be in No Status.

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

## Project Board Sync — MANDATORY

Every status change to a GitHub issue MUST be reflected on the project board in the same operation. The board is the source of truth; issue state alone is not enough.

### Who runs gh commands

Agents run gh commands as part of their unit of work. When an agent completes an issue, they handle the full lifecycle: open the PR, merge it after pre-merge verification, close the issue, move the board status to Done, add or remove labels as needed, post relevant comments. The TERMINAL REPORT confirms what was done — it does not punt gh commands to Jason or Claude Code chat for follow-up action. Chat Claude can also run gh commands directly for orchestration work (creating new issues, batch board updates, milestone management). Jason can run standalone gh commands in the macOS terminal if it's convenient or the work is independent of any agent or chat session, but the default for any work that is part of an active unit is: the agent or Claude Code session that owns the work executes the gh commands. The "report status changes for Jason to action" pattern is deprecated — do not generate it.

### Status transitions and required board moves

| Trigger | Board action |
|---|---|
| Agent picks up issue / starts work | Move to **In Progress** (b5cce126) |
| PR opened referencing issue | Ensure issue is **In Progress** |
| PR merged + issue closed | Move to **Done** (39656e02) |
| Issue closed without PR (won't fix, duplicate, already resolved) | Move to **Done** (39656e02) |
| Issue reset / deprioritized | Move to **Backlog** (ca2d7b25) |

### New issue creation — board status gotcha

`gh issue create --project "PackList"` adds the issue to the board but leaves it in **No Status**, not Backlog. Every new issue creation must be immediately followed by a board-edit command to set the status to Backlog.

**Single issue:**
```bash
# Step 1 — create the issue and capture the number
NUM=$(gh issue create --repo jasonegray/travel --title "..." --body "..." | grep -o '[0-9]*$')

# Step 2 — set board status to Backlog
gh api graphql -f query="mutation {
  updateProjectV2ItemFieldValue(input: {
    projectId: \"PVT_kwHOEMO09M4BWtlG\"
    itemId: \"$(gh api graphql -f query='{ repository(owner: \"jasonegray\", name: \"travel\") { issue(number: '$NUM') { projectItems(first: 1) { nodes { id } } } } }' --jq '.data.repository.issue.projectItems.nodes[0].id')\"
    fieldId: \"PVTSSF_lAHOEMO09M4BWtlGzhR_g7M\"
    value: { singleSelectOptionId: \"ca2d7b25\" }
  }) { projectV2Item { id } }
}"
```

**Batch (multiple new issues):**
```bash
for num in N1 N2 N3; do
  item_id=$(gh api graphql -f query="{ repository(owner: \"jasonegray\", name: \"travel\") { issue(number: $num) { projectItems(first: 1) { nodes { id } } } } }" --jq '.data.repository.issue.projectItems.nodes[0].id')
  gh api graphql -f query="mutation { updateProjectV2ItemFieldValue(input: { projectId: \"PVT_kwHOEMO09M4BWtlG\" itemId: \"$item_id\" fieldId: \"PVTSSF_lAHOEMO09M4BWtlGzhR_g7M\" value: { singleSelectOptionId: \"ca2d7b25\" } }) { projectV2Item { id } } }"
  echo "✓ #$num → Backlog"
done
```

**Verification:**
```bash
gh api graphql -f query='{ repository(owner: "jasonegray", name: "travel") { issue(number: N) { projectItems(first: 1) { nodes { fieldValues(first: 10) { nodes { ... on ProjectV2ItemFieldSingleSelectValue { name field { ... on ProjectV2SingleSelectField { name } } } } } } } } } }' --jq '.data.repository.issue.projectItems.nodes[0].fieldValues.nodes[] | select(.field.name == "Status") | .name'
```

Claude (chat) MUST include the board-status command paired with every `gh issue create` it generates. Never give Jason a `gh issue create` command without the paired Backlog-set command.

### Required command pattern

When closing or transitioning an issue, run BOTH the issue command AND the board update:

```bash
# Example: closing issue #N as done
gh issue close N -c "<reason>"
gh project item-edit \
  --project-id PVT_kwHOEMO09M4BWtlG \
  --id $(gh project item-list 1 --owner jasonegray --format json --limit 200 | jq -r '.items[] | select(.content.number==N) | .id') \
  --field-id PVTSSF_lAHOEMO09M4BWtlGzhR_g7M \
  --single-select-option-id 39656e02
```

### Agent responsibilities

- Terminal agents do NOT run `gh` commands. They report status changes in their TERMINAL REPORT.
- Jason runs `gh` commands in the Mac terminal.
- Claude (chat) MUST include the board-update command alongside every issue command it generates. Never give Jason a `gh issue close` or status change command without the paired `gh project item-edit`.
- If a TERMINAL REPORT indicates an issue is complete, the response MUST include the board-move command, not just the close command.

### Field reference

- Project: PVT_kwHOEMO09M4BWtlG
- Status field: PVTSSF_lAHOEMO09M4BWtlGzhR_g7M
- Backlog: ca2d7b25
- In Progress: b5cce126
- Done: 39656e02

## Pre-merge verification — MANDATORY

> **Background:** PR #201 shipped `CNContactStore.unifiedMeContact(withKeys:)` which does not exist on iOS, broke the simulator build, and was caught only after merge because unit tests mocked the framework. This rule prevents that class of failure.

### Rule 1 — SDK API verification

Any agent writing code against an iOS framework (Contacts, HealthKit, EventKit, CoreLocation, CloudKit, AuthenticationServices, etc.) must verify that every framework method or property used actually exists in the current iOS SDK before writing the code.

**"Verify" means one of:**
- Citing the Apple developer documentation URL in the PR description (e.g. `https://developer.apple.com/documentation/contacts/...`)
- Grepping the SDK headers: `find $(xcrun --show-sdk-path)/System/Library/Frameworks -name "*.h" | xargs grep -l "methodName"`

**Does not count as verification:**
- Unit tests that mock the framework object — mocks compile against your own fake, not the SDK
- Assuming a method exists because it "sounds right"
- Citing a Stack Overflow answer or LLM output without an Apple docs URL

If a method cannot be verified against Apple docs, do not use it. Find the correct API that does exist.

### Rule 2 — Simulator build gate

Unit tests passing is necessary but not sufficient. Before opening a PR, the agent must run a simulator build and confirm it compiles against the real SDK:

```bash
xcodebuild -scheme PackList -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

The TERMINAL REPORT must include either the full build output or an explicit "Build succeeded" confirmation. The PR description must also include this confirmation.

**No PR may be opened without a passing simulator build. Tests alone do not clear this bar.**

## Local verification refresh — always include before manual testing

Any time Claude (chat) asks Jason to smoke-test, manually verify, or visually check work on the simulator after merges have landed, the response must include the local refresh command sequence so Jason isn't building against stale code or stale build artifacts.

**Mandatory sequence — include this verbatim in every simulator verification ask:**

In Terminal:
```bash
cd ~/Documents/Projects/PackList
git checkout main
git pull
```

Then in Xcode:
- **Shift+Cmd+K** — Clean Build Folder
- **Cmd+B** — Build
- **Cmd+R** — Run on simulator

Never ask Jason to verify on the simulator without these instructions in the same response. Skipping any step risks building against stale code, stale build artifacts, or both.

**Mandatory checklist — include a specific smoke test checklist in every simulator verification ask:**

When asking Jason to smoke-test, also provide a numbered checklist tied to the work that merged in the current session. Name each issue or PR by number, describe the specific flow to walk, and state the expected behavior. Generic "go try the app" instructions are not acceptable.

Format:

> Smoke test these flows on simulator:
> 1. **#203 (extras tile sizing)** — start a new trip, get to the extras screen, confirm all option tiles render at the same size including longer labels.
> 2. **#204 (keyboard dismiss)** — on Where Are You Headed, type a destination, tap a result — keyboard should dismiss immediately.
> 3. **#205 (first trip refresh)** — fresh app launch with no trips, create your first trip, confirm it appears on Trips list without tab-switching.
> 4. **#207 (Flight Pouch removal)** — open a trip detail, confirm no standalone Flight Pouch section at top, but Flight Pouch still accessible via bag swipe.

Every simulator verification ask must include both: (1) the git pull + Xcode refresh sequence above, and (2) a numbered checklist with issue/PR references and specific expected behaviors.

## Device-only validation rule

Some classes of bugs reproduce only on real hardware, not on simulator. Common categories include keyboard behavior, SwiftData refresh timing under real-device main-thread pressure, haptic feedback, camera and contacts permission flows, background task behavior, and most performance issues.

When an agent fixes a bug in one of these categories:

1. The agent's PR description must explicitly note "simulator passes but original bug requires device validation to confirm fix"
2. After the PR merges, the issue must be tagged with the `device-validation-required` label
3. Chat Claude, when generating smoke test checklists, must flag which items require device validation and which can be confirmed on simulator

This prevents the false-completeness pattern where unit tests plus simulator build success are mistaken for actual fix validation on a bug class where the simulator cannot reproduce the original problem.

## Research spike conventions

> **Background:** Spike #217 recommended AeroDataBox without addressing backend architecture, exposing an API key in the iOS binary as a deployment plan. These rules prevent that class of incomplete analysis.

### Rule 1 — Spike output format

Research spikes must produce an options analysis with explicit tradeoffs and a recommended next decision — not a single-answer recommendation.

Required format:
- Candidate options with strengths and weaknesses for each
- A scoring or comparison framework applied consistently across candidates
- A recommended next step (which may be "do a second pass with sharper criteria" rather than "pick the winner")

Spikes that return only a single recommendation without surfacing alternatives and tradeoffs will be rejected and re-run. The purpose of a spike is to give Jason enough structured information to make a well-informed decision, not to make the decision for him.

### Rule 2 — External API spike requirements

Any spike evaluating an external API or third-party service must address all of the following in the deliverable:

- **(a) Credential storage and request architecture** — client-side API keys are extractable from app binaries and are never acceptable for production. The spike must propose a backend proxy architecture or explain why one is not needed.
- **(b) Caching strategy and cost modeling** — estimate request volume at expected usage scale and document the cost. Identify what can be cached and for how long.
- **(c) Graceful degradation** — describe how the app behaves if the service is unavailable, rate-limited, or returns unexpected data.
- **(d) Privacy implications** — identify any user data transmitted to the third party and document required privacy disclosures. Flag any App Store privacy nutrition label updates required.
- **(e) Cost projection with kill criteria** — project cost at indie/side-project scale (e.g. 500 MAU). Define a specific kill criterion: the condition under which the integration would be abandoned.

Spikes that recommend an API without addressing all five points will be rejected.

## Terminal report format

```
TERMINAL REPORT — T[N]
Issue: #[N] [title]
Status: COMPLETE | NEEDS JASON
PR: #[N] [url] — merged
Files changed: [list]
Summary: [1-2 sentences max]
If NEEDS JASON: [one sentence]
Next: ready for new assignment
```
