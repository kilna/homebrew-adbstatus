#!/bin/bash
set -euo pipefail

# Define paths
SCRIPT_PATH="/usr/local/bin/adb-status-httpd.py"
MONITOR_SCRIPT_PATH="/usr/local/bin/adb_monitor.py"
PLIST_PATH="$HOME/Library/LaunchAgents/com.user.adb-status.plist"
MONITOR_PLIST_PATH="$HOME/Library/LaunchAgents/com.user.adb-monitor.plist"
CERT_DIR="/usr/local/etc/adb-status"
PID_FILE="$HOME/.sleepwatcher_monitor.pid"

echo "Uninstalling ADB status and monitor services..."

# Unload LaunchAgents if they exist
if [ -f "$PLIST_PATH" ]; then
  echo "Unloading ADB status service..."
  launchctl unload "$PLIST_PATH" 2>/dev/null || true
  echo "Removing LaunchAgent plist for ADB status..."
  rm -f "$PLIST_PATH"
fi

if [ -f "$MONITOR_PLIST_PATH" ]; then
  echo "Unloading ADB monitor service..."
  launchctl unload "$MONITOR_PLIST_PATH" 2>/dev/null || true
  echo "Removing LaunchAgent plist for ADB monitor..."
  rm -f "$MONITOR_PLIST_PATH"
fi

# Kill any running sleepwatcher processes
echo "Stopping sleepwatcher processes..."
if command -v pkill &>/dev/null; then
  pkill -f sleepwatcher || true
fi

# Remove PID file
if [ -f "$PID_FILE" ]; then
  echo "Removing PID file..."
  rm -f "$PID_FILE"
fi

# Remove installed files
echo "Removing installed scripts..."
sudo rm -f "$SCRIPT_PATH"
sudo rm -f "$MONITOR_SCRIPT_PATH"
sudo rm -f /usr/local/bin/adb_info.py
sudo rm -f /usr/local/bin/sleep_monitor.py
sudo rm -f /usr/local/bin/adb-monitor.yml

# Ask if certificates should be removed
read -p "Do you want to remove SSL certificates? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
  echo "Removing SSL certificates..."
  sudo rm -rf "$CERT_DIR"
fi

# Ask if sleepwatcher should be uninstalled
read -p "Do you want to uninstall sleepwatcher? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
  echo "Uninstalling sleepwatcher..."
  brew uninstall sleepwatcher
  
  # Remove symlink if it exists
  if [ -L "/usr/local/bin/sleepwatcher" ]; then
    sudo rm -f /usr/local/bin/sleepwatcher
  fi
fi

# Remove log files
read -p "Do you want to remove log files? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
  echo "Removing log files..."
  rm -f "$HOME/Library/Logs/adb-status.log"
  rm -f "$HOME/Library/Logs/adb-monitor.log"
  rm -f "$HOME/Library/Logs/adb-monitor-error.log"
fi

echo "Uninstallation complete!"
echo "The following Python packages were used by the ADB monitor:"
echo "  - psutil"
echo "  - pyyaml"
echo "If you no longer need these packages, you can remove them with:"
echo "  pip3 uninstall psutil pyyaml" 