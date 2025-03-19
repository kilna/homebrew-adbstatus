# Homebrew Tap for ADBStatus

This tap provides Homebrew formulae for [ADBStatus](https://github.com/kilna/adbstatus), an Android Debug Bridge (ADB) device monitor with sleep/wake support.

## Installation

```bash
# First, tap the repository
brew tap kilna/adbstatus

# Then install the package
brew install --HEAD adbstatus
```

## Starting Services

ADBStatus provides two services that can be started with Homebrew:

```bash
# Start the ADBStatus server
brew services start adbstatus-server

# Start the ADBStatus monitor
brew services start adbstatus-monitor
```

## Configuration

Configuration files are installed to:
- `/usr/local/etc/adbstatus/` (or your Homebrew prefix)

SSL certificates are automatically generated during installation at:
- `/usr/local/etc/adbstatus/ssl/`

## Requirements

The formula takes care of installing Python dependencies, but requires:
- Python 3.8 or newer
- sleepwatcher (automatically installed as a dependency)

## Development

If you want to modify the formula:

1. Clone this repository:
   ```bash
   git clone https://github.com/kilna/homebrew-adbstatus.git
   ```

2. Edit the formula in `Formula/adbstatus.rb`

3. Test installation:
   ```bash
   brew install --HEAD --build-from-source --force ./Formula/adbstatus.rb
   ```

## Troubleshooting

If you encounter issues with the installation:

1. Ensure Python 3.8+ is installed and working correctly
2. Try reinstalling with:
   ```bash
   brew uninstall --force adbstatus
   brew cleanup
   brew install --HEAD --build-from-source --force adbstatus
   ```

3. Verify that pip3 is available and working:
   ```bash
   which pip3
   pip3 --version
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

## Logs

Log files are located at:

## Author

Kilna, Anthony <kilna@kilna.com>

## License

MIT