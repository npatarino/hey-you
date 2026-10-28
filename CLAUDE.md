# Hey You! — agent instructions

macOS menu-bar app (Swift 6, SwiftUI + AppKit, **TCA**) that takes over every screen with a red alert one minute before a Google Calendar meeting. Target: Mac App Store.

**Product spec (what and why): [docs/PRD.md](docs/PRD.md). Technical plan and milestones (how): [PLAN.md](PLAN.md). Read both entirely before doing anything, then execute the milestones in order, autonomously.** Do not reopen architecture decisions from PLAN.md §1.

## Environment facts (checked 2026-10-28)
- Swift 6.3.3 via Command Line Tools. **Xcode.app is NOT installed**: `swift build` works, `swift test`/`xcodebuild` do not. Check again at start (`ls /Applications | grep Xcode`); if still missing, do everything possible with `swift build` and tell the user plainly which milestones (7–9) are blocked and how to unblock (install Xcode, `sudo xcode-select -s /Applications/Xcode.app`).
- `brew` is at `/opt/homebrew/bin/brew`. Install `xcodegen swiftlint swiftformat` first.
- Google OAuth client ID and Apple Team ID are user-provided secrets in `Config/Secrets.xcconfig` (gitignored). Never commit them. Develop against mocks when missing.

## Commands
```bash
cd HeyYouKit && swift build            # compile all logic
cd HeyYouKit && swift test             # needs Xcode
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
