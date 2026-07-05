# Architecture

## Targets

| Target | Role |
|--------|------|
| `PomopomoKit` | Testable core: engine, settings, logging, formatters |
| `Pomopomo` | AppKit/SwiftUI executable: menu bar, panel, menus |
| `PomopomoTests` | Unit tests for engine and markdown rendering |

## State Machine

Each phase (Pomodoro, Break) moves through:

```
idle → running → paused → completed
         ↓ skip (from running/paused/completed)
       next phase
```

`PomodoroEngine` is the single source of truth (`@Observable`, `@MainActor`). A 1-second `Timer` drives ticks; the status item and SwiftUI views observe the engine.

## UI Layers

```
AppDelegate
  └── AppCoordinator (logging, settings actions, engine delegate)
        └── StatusItemController (NSStatusItem + panel toggle)
              └── TimerPanel (borderless NSPanel, .floating)
                    └── TimerView (SwiftUI)
                          ├── GlassBackground (NSVisualEffectView)
                          ├── ProgressDots
                          └── ControlsView
```

`GlassBackground` uses `NSVisualEffectView` with `.hudWindow` material (macOS 15 compatible; no Liquid Glass API).

## Logging

`ActivityLogger` writes to `~/Documents/Pomopomo/YYYY-MM-DD/YYYY-MM-DD.md`. On each event it:

1. Reads the existing file (if any)
2. Parses summary + timeline via `MarkdownRenderer`
3. Applies the event to the summary
4. Appends a timeline line
5. Rewrites the full document atomically

Day rollover is automatic: events after midnight go to the new day's file.

## Settings

Persisted in `UserDefaults`: Pomodoro duration, break duration, auto-start, completed pomodoros in current cycle.

## Launch at Login

`LaunchAtLogin.register()` wraps `SMAppService.mainApp.register()`. Failures are silent for unsigned builds; see README for LaunchAgent fallback.
