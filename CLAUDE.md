# Hey You! — agent instructions

macOS menu-bar app (Swift 6, SwiftUI + AppKit, **TCA**) that takes over every screen with a red alert one minute before a Google Calendar meeting. Target: Mac App Store.

**Product spec (what and why): [docs/PRD.md](docs/PRD.md). Technical plan and milestones (how): [PLAN.md](PLAN.md). Read both entirely before doing anything, then execute the milestones in order, autonomously.** Do not reopen architecture decisions from PLAN.md §1.

## Environment facts (checked 2026-10-29)
- Xcode 27.1 is installed as `/Applications/Xcode-27.1.0.app`, but `xcode-select` points at the Command Line Tools. `source scripts/env.sh` sets `DEVELOPER_DIR` so `swift test`, `xcodebuild` and `swiftlint` work; all scripts do this. (Or run `sudo xcode-select -s /Applications/Xcode-27.1.0.app`.)
- `brew` is at `/opt/homebrew/bin/brew`; `xcodegen swiftlint swiftformat` are installed.
- Google OAuth client ID, PostHog key and Apple Team ID are user-provided secrets in `Config/Secrets.xcconfig` (gitignored). Never commit them. Develop against mocks when missing.
- The agent shell has no Screen Recording or Accessibility permission: it can't screenshot the real app or send it keys. Use the window server (`CGWindowListCopyWindowInfo`), `sample`, and the snapshot renders instead.

## Commands
```bash
cd HeyYouKit && swift build            # compile all logic
./scripts/test.sh                      # package tests (swift test)
./scripts/test.sh --xcode              # + app-hosted StoreKit tests
xcodegen generate                      # regenerate HeyYou.xcodeproj from project.yml
xcodebuild -scheme HeyYou -configuration Debug build   # needs Xcode
swiftformat . && swiftlint
```

## Conventions
- All logic lives in the local package `HeyYouKit`; `App/` is wiring only.
- TCA: `@Reducer`, `@ObservableState`, `@Dependency`, `@DependencyClient`, `@Shared(.appStorage)`. Verify APIs against the resolved version in `HeyYouKit/.build/checkouts/swift-composable-architecture` before writing code.
- Strict concurrency complete. No force unwraps, no `try!` outside tests, no `Date()` in reducers (use `@Dependency(\.date)` / `continuousClock`).
- Every reducer has `TestStore` tests (Swift Testing). Pure logic (scheduler, link parser) is 100 % tested.
- UI strings via `String(localized:)`, catalog `Localizable.xcstrings`, English base + Spanish.
- Build after every feature. A milestone is not done until it compiles. One commit per milestone minimum, conventional commit messages in English, never force-push.
- Report honestly at the end: what was verified, what was not.
- Architecture and deviations from PLAN.md: [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md). QA status: [docs/QA.md](docs/QA.md).
- When editing files with scripts, assert that each replacement matched (SwiftFormat rewrites code, so old snippets may not exist).
