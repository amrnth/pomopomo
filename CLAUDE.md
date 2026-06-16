# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Pomopomo is a native macOS menu-bar Pomodoro timer built with Swift Package Manager (no Xcode project required). It displays a live countdown in the menu bar, provides a frosted-glass panel UI, and automatically logs all activity to daily markdown files in `~/Documents/Pomopomo/`.

## Build & Development Commands

```bash
# Build debug binary
swift build

# Run all unit tests
swift test

# Run a specific test
swift test --filter PomopomoTests.EngineTests/testPlayPause

# Build and launch the app (creates build/Pomopomo.app)
bash Scripts/run.sh

# Build app bundle only (without launching)
bash Scripts/bundle.sh
```

The app bundle is assembled at `build/Pomopomo.app` by copying the release binary from `.build/release/Pomopomo` and the `Resources/Info.plist` into the standard macOS app structure.

## Architecture Overview

### Package Targets

- **PomopomoKit**: Core business logic (engine, settings, logging, formatters). Fully testable, no AppKit/SwiftUI dependencies.
- **Pomopomo**: AppKit/SwiftUI executable (menu bar, panel, menus, sound). Depends on PomopomoKit.
- **PomopomoTests**: Unit tests for PomopomoKit.

### State Machine & Timer Flow

The `PomodoroEngine` (PomopomoKit/Core/PomodoroEngine.swift) is the single source of truth, marked `@Observable` and `@MainActor`. Each phase (PomoPomo or Break) transitions through:

```
idle → running → paused → completed
        ↓ skip (from any state)
      next phase
```

A 1-second `Timer` drives `tick()` calls. The engine maintains an `endDate` (calculated from remaining seconds) and syncs on each tick to handle system sleep/wake correctly.

**Key engine methods:**
- `togglePlayPause()`: Start/pause/resume based on current state
- `skip()`: Force transition to next phase, preserving running state if skipped while running
- `fastForward(seconds:)`: Subtract seconds from remaining time while running; triggers completion if time reaches zero
- `tick()`: Called every second to update remaining time and detect completion
- `prepareForNextPhase(autoStart:)`: Transition to next phase with optional auto-start

### Pomodoro Cycle Tracking

The engine tracks `completedPomodorosInCycle` (0-3) to display progress dots. After 4 completed pomodoros, the cycle resets to 0. The `currentPomodoroNumber` is derived from this count: `(completedPomodorosInCycle % 4) + 1`.

**Important:** The cycle advances when a pomodoro is completed (naturally or via skip), not when starting one. Breaking from phase PomoPomo to phase Break increments the cycle.

### UI Hierarchy

```
AppDelegate (NSApplicationDelegate)
  └── AppCoordinator (engine delegate, logging coordinator)
        └── StatusItemController (manages NSStatusItem + panel toggle)
              └── TimerPanel (borderless NSPanel with .floating level)
                    └── TimerView (SwiftUI root view)
                          ├── GlassBackground (NSVisualEffectView with .hudWindow material)
                          ├── ProgressDots (4-dot cycle indicator)
                          └── ControlsView (play/pause, skip, settings buttons)
```

**GlassBackground** wraps `NSVisualEffectView` to achieve the frosted-glass effect. It uses `.hudWindow` material (macOS 15 compatible).

**AppCoordinator** is the glue layer:
- Implements `PomodoroEngineDelegate` to react to engine state changes
- Calls `ActivityLogger.log()` for all user actions and phase transitions
- Triggers `SoundPlayer` for audio feedback
- Builds and displays the settings menu
- Starts the MCP server at launch for agent control

### Activity Logging

`ActivityLogger` (PomopomoKit/Logging/ActivityLogger.swift) writes to `~/Documents/Pomopomo/YYYY-MM-DD/YYYY-MM-DD.md`. On each event:

1. Reads the existing file (if any)
2. Parses summary + timeline via `MarkdownRenderer`
3. Applies the event to the summary (updates pomodoro count, focus minutes, first/last activity)
4. Appends a timestamped line to the timeline
5. Rewrites the full document atomically

Day rollover is automatic: events after midnight go to the new day's file.

**Log events** (PomopomoKit/Logging/LogEvent.swift):
- `pomoPomoStarted`, `pomoPomoCompleted`, `pomoPomoPaused`, `pomoPomoResumed`, `pomoPomoSkipped`
- `pomoPomoFastForwarded`
- `breakStarted`, `breakCompleted`, `breakSkipped`
- `pomoPomoDurationChanged`, `breakDurationChanged`, `autoStartToggled`, `timerReset`
- `appLaunched`, `appQuit`, `panelOpened`

### MCP Server (Agent Control)

An embedded MCP (Model Context Protocol) HTTP server starts at launch, allowing agents (Claude Code, etc.) to control the timer programmatically. It listens on `127.0.0.1:6390/mcp` using Streamable HTTP transport with SSE.

**Architecture:**
- `MCPService` (Pomopomo/MCP/MCPService.swift): Lifecycle manager, starts/stops the NIO HTTP server in a detached task
- `MCPToolRouter` (Pomopomo/MCP/MCPToolRouter.swift): Defines 7 tools and dispatches calls to `AppCoordinator` via `MainActor.run {}`
- `NIOHTTPAdapter` (Pomopomo/MCP/NIOHTTPAdapter.swift): SwiftNIO-based HTTP server adapted from the MCP SDK's conformance example

**Available tools:**
| Tool | Description |
|------|-------------|
| `get_status` | Current phase, state, remaining/total seconds, pomodoro number, progress |
| `play_pause` | Toggle play/pause/resume |
| `skip` | Skip to next phase |
| `fast_forward` | Subtract N seconds from remaining time (requires `seconds` param) |
| `reset` | Full timer reset |
| `get_settings` | Read pomodoro/break duration, auto-start |
| `update_settings` | Change duration or auto-start settings |

**Concurrency bridge:** The MCP `Server` is an actor; tool handler closures are `@Sendable`. `AppCoordinator` and `PomodoroEngine` are `@MainActor`. The bridge uses `CoordinatorRef` (`@unchecked Sendable` wrapper) with all access going through `await MainActor.run {}`.

### Settings Persistence

`Settings` (PomopomoKit/Settings/Settings.swift) is persisted in `UserDefaults` via `SettingsStore`. Key fields:
- `pomoPomoDurationMinutes` (default 25)
- `breakDurationMinutes` (default 5)
- `autoStart` (default false)
- `completedPomodorosInCycle` (0-3, tracks cycle progress across app restarts)

The engine reloads settings via `reloadSettings()` when needed. Settings changes that affect idle timers trigger immediate UI updates.

### Testing Utilities

`PomodoroEngine` includes test-only methods prefixed with `test_` to directly manipulate state for unit tests:
- `test_setPhase(_:)`
- `test_setState(_:)`
- `test_setRemainingSeconds(_:)`
- `test_setCompletedInCycle(_:)`

Use these to set up specific engine states in tests without triggering side effects.

### Launch at Login

`LaunchAtLogin.register()` (Pomopomo/Login/LaunchAtLogin.swift) wraps `SMAppService.mainApp.register()`. Unsigned dev builds often fail registration silently. For development, use the LaunchAgent fallback documented in README.md.

## Code Patterns & Conventions

- **Main actor isolation**: All UI and engine code runs on `@MainActor`. The engine's `Timer` callbacks explicitly dispatch to main.
- **Dependency injection**: The engine and logger accept `Clock`, `Calendar`, `FileManager` for testability. Use `SystemClock()` in production, mock clocks in tests.
- **Observable pattern**: SwiftUI views observe the `@Observable` engine. AppKit components implement `PomodoroEngineDelegate` for callbacks.
- **Thread safety in logger**: `ActivityLogger` is `@unchecked Sendable` and uses `NSLock` to serialize file writes, since logging can be triggered from any thread.

## Common File Locations

- Core engine: `Sources/PomopomoKit/Core/PomodoroEngine.swift`
- App coordinator: `Sources/Pomopomo/App/AppCoordinator.swift`
- Menu bar status item: `Sources/Pomopomo/MenuBar/StatusItemController.swift`
- SwiftUI panel: `Sources/Pomopomo/MenuBar/TimerPanel.swift` and `Sources/Pomopomo/Views/TimerView.swift`
- Activity logger: `Sources/PomopomoKit/Logging/ActivityLogger.swift`
- Markdown rendering: `Sources/PomopomoKit/Logging/MarkdownRenderer.swift`
- Settings: `Sources/PomopomoKit/Settings/Settings.swift`
- MCP server: `Sources/Pomopomo/MCP/` (MCPService, MCPToolRouter, NIOHTTPAdapter)
- Tests: `Tests/PomopomoTests/`

## Platform Requirements

- macOS 15+ (`.macOS(.v15)` in Package.swift)
- Swift 6.1+ (Command Line Tools)
- Dependencies: [MCP Swift SDK](https://github.com/modelcontextprotocol/swift-sdk), [SwiftNIO](https://github.com/apple/swift-nio), [swift-log](https://github.com/apple/swift-log) (MCP server only; PomopomoKit remains dependency-free)
