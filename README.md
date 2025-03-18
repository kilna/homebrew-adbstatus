# ADB Status Homebrew Tap

This tap installs ADB Status, an Android Debug Bridge (ADB) device monitor with sleep/wake support.

## Installation

```bash
# Install the tap
brew tap yourusername/adbstatus
# Install ADB Status
brew install adbstatus
```

## Features

- Monitors Android devices connected via ADB
- Automatically restores ADB connections after Mac sleep/wake cycles
- Provides a secure HTTPS server for device status
- Integrates with sleepwatcher for system event handling

## Usage

After installation, services will automatically start:

```bash
# Manually start/stop services
brew services start adbstatus
brew services stop adbstatus

# Check status
brew services list | grep adbstatus
```

## Logs

Log files are located at:
- `~/Library/Logs/adb-status.log`
- `~/Library/Logs/adb-monitor.log`

## Uninstallation

```bash
brew uninstall adbstatus
```

## License

MIT
