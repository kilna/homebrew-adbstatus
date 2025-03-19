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
# Start/stop individual services
brew services start adbstatus-server
brew services start adbstatus-monitor
brew services stop adbstatus-server
brew services stop adbstatus-monitor

# Check status
brew services list | grep adbstatus
```

You can also use the command-line tools directly:

```bash
# Check ADB device status
adbstatus              # JSON output
adbstatus -t           # Text output

# Server management
adbstatus-server start
adbstatus-server stop
adbstatus-server status
adbstatus-server status -d  # Include device info

# Monitor management
adbstatus-monitor start
adbstatus-monitor stop
adbstatus-monitor status
adbstatus-monitor status -d  # Include device info
adbstatus-monitor status -s  # Include server status
```

## Configuration

Edit the configuration files at:

## Logs

Log files are located at:

## Author

Kilna, Anthony <kilna@kilna.com>

## License

MIT