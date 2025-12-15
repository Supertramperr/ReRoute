# ReRoute — Handoff

## What this is
macOS menu bar app for rebooting a router + showing status/progress.

## Key files / entry points
- `Sources/ReRouteApp.swift` — app entry
- `Sources/AppModel.swift` — state machine (operation/progress), triggers reboot
- `Sources/RouterClient.swift` — router HTTP/login/reboot call(s)
- `Sources/Utils/InternetProbe.swift` — connectivity checks (online/offline)
- `Sources/Views/RootMenuView.swift` — main menu UI
- `Sources/Views/MoreView.swift` — “More” submenu UI
- `Sources/Views/StatusBlockView.swift` — status/progress UI block
- `Sources/Views/MenuBarIconView.swift` — menu bar icon state mapping
- `Sources/Views/AboutView.swift` — About window
- `Sources/Views/SettingsView.swift` — Settings window

## Build / Run
- Open `ReRoute.xcodeproj`
- Build scheme: `ReRoute` (Debug)

## Git workflow
- Default branch: `main`
- Keep experimental work on feature branches.

## Safety / secrets
- Router credentials live in app settings; do not commit real credentials.
- If you add any tokens/keys, keep them out of Git.

## Current UI behavior (high level)
- Main menu + More submenu use tighter clickable rows.
- Online pill is green; Offline is red.
- “Verifying” phase removed; show only “Rebooting…” during reboot.

## Backups
- `Sources/_backups/` contains snapshots and is intentionally untracked.

## TODO / next improvements
- (Fill in as you go)

## Security note (2025-12-15)
- Removed hardcoded defaults for router username/password in `Sources/AppModel.swift`.
- Credentials must be entered via Settings (stored via AppStorage).

## Working agreement (for future ChatGPT sessions)
- Always make changes via a single bash snippet that:
  1) creates a timestamped backup under `Sources/_backups/<timestamp>-<topic>/`
  2) applies edits
  3) runs `xcodebuild` and relaunches the app
- If build fails, revert by copying from the last backup folder and rebuilding.

## Quick rollback recipes
### Roll back a single file from a backup folder
Example:
  cp "Sources/_backups/<timestamp>-<topic>/RootMenuView.swift" "Sources/Views/RootMenuView.swift"
  xcodebuild -project ReRoute.xcodeproj -scheme ReRoute -destination "platform=macOS" -configuration Debug build

## Maintenance scripts
- `Scripts/doctor.sh` — sanity checks (list project, clean build, quick scans)
- `Scripts/handoff.sh` — creates `ReRoute-handoff-YYYYMMDD-HHMMSS.tgz` excluding junk
