# Pomopomo

A native macOS menu-bar PomoPomo timer built with Swift Package Manager — no Xcode project required.

## Build & Run

```bash
# Compile debug build
swift build

# Run unit tests
swift test

# Build release app bundle and launch
bash Scripts/run.sh
```

The app bundle is assembled at `build/Pomopomo.app` by `Scripts/bundle.sh`.

## Features

- Live countdown in the menu bar (`25:00` format, ticks every second while running)
- Click the status item to toggle a compact frosted-glass panel
- PomoPomo / Break phases with play, pause, and skip
- Progress dots for the current 4-pomodoro cycle
- Settings menu (⋮): PomoPomo/break durations, auto-start, quit
- Daily markdown activity log
- Built-in MCP server for agent control (Claude Code, etc.)

## Activity Logs

Logs are written to:

```
~/Documents/Pomopomo/YYYY-MM-DD/YYYY-MM-DD.md
```

Each file contains a live **Summary** (pomodoros completed, focus minutes, first/last activity) and an append-only **Timeline** of timestamped events.

## Launch at Login

On startup the app calls `SMAppService.mainApp.register()` to register for launch at login.

**Unsigned dev builds** often fail this registration. If launch-at-login does not work, use this LaunchAgent fallback:

1. Build the app: `bash Scripts/bundle.sh`
2. Create `~/Library/LaunchAgents/com.amrnth.pomopomo.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.amrnth.pomopomo</string>
    <key>ProgramArguments</key>
    <array>
        <string>/ABSOLUTE/PATH/TO/pomopomo/build/Pomopomo.app/Contents/MacOS/Pomopomo</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
</dict>
</plist>
```

3. Load it: `launchctl load ~/Library/LaunchAgents/com.amrnth.pomopomo.plist`

Replace the path with your actual build location. Unload with `launchctl unload` when removing.

## MCP Server

When the app launches, it starts an MCP (Model Context Protocol) HTTP server on `127.0.0.1:6390/mcp`. This allows AI agents to control the timer programmatically.

**Available tools:** `get_status`, `play_pause`, `skip`, `fast_forward`, `reset`, `get_settings`, `update_settings`

To connect from Claude Code, add to your MCP config:

```json
{
  "mcpServers": {
    "pomopomo": {
      "type": "streamable-http",
      "url": "http://127.0.0.1:6390/mcp"
    }
  }
}
```

## Requirements

- macOS 15+
- Swift 6.1+ (Command Line Tools)

## Architecture

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).
