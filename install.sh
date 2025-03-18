#!/bin/bash
set -euo pipefail

# Define paths
SCRIPT_PATH="/usr/local/bin/adb-status-httpd.py"
MONITOR_SCRIPT_PATH="/usr/local/bin/adb_monitor.py"
PLIST_PATH="$HOME/Library/LaunchAgents/com.user.adb-status.plist"
CERT_DIR="/usr/local/etc/adb-status"
CERT_FILE="$CERT_DIR/cert.pem"
KEY_FILE="$CERT_DIR/key.pem"

# Check if Homebrew is installed
if ! command -v brew &> /dev/null; then
  echo "Homebrew is not installed. Please install it first:"
  echo "/bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
  exit 1
fi

# Install sleepwatcher if not already installed
echo "Checking for sleepwatcher..."
if ! brew list sleepwatcher &> /dev/null; then
  echo "Installing sleepwatcher..."
  brew install sleepwatcher
else
  echo "sleepwatcher is already installed"
fi

# Ensure sleepwatcher is in PATH or accessible
if ! command -v sleepwatcher &> /dev/null; then
  # Add link to /usr/local/bin for easier access
  echo "Creating symbolic link for sleepwatcher..."
  if [ -f "/usr/local/sbin/sleepwatcher" ]; then
    sudo ln -sf /usr/local/sbin/sleepwatcher /usr/local/bin/sleepwatcher
  elif [ -f "/opt/homebrew/bin/sleepwatcher" ]; then
    sudo ln -sf /opt/homebrew/bin/sleepwatcher /usr/local/bin/sleepwatcher
  fi
fi

# Install Python dependencies
echo "Installing Python dependencies..."
if [ -f "requirements.txt" ]; then
  pip3 install -r requirements.txt
else
  echo "No requirements.txt found, installing dependencies manually..."
  pip3 install psutil pyyaml
fi

# Create certificate directory
echo "Creating certificate directory..."
sudo mkdir -p "$CERT_DIR"

# Generate self-signed certificate if it doesn't exist
if [[ ! -f "$CERT_FILE" || ! -f "$KEY_FILE" ]]; then
  echo "Generating self-signed SSL certificate..."
  sudo openssl req -new -x509 -keyout "$KEY_FILE" -out "$CERT_FILE" \
    -days 3650 -nodes -subj "/CN=adb-status-server" 2>/dev/null
  sudo chmod 644 "$CERT_FILE"
  sudo chmod 600 "$KEY_FILE"
  echo "Certificate generated successfully"
else
  echo "Using existing certificate"
fi

# Copy scripts to system location
echo "Installing adb-status-httpd.py to $SCRIPT_PATH..."
sudo cp adb-status-httpd.py $SCRIPT_PATH
sudo chmod +x $SCRIPT_PATH

echo "Installing adb_monitor.py to $MONITOR_SCRIPT_PATH..."
sudo cp adb_monitor.py $MONITOR_SCRIPT_PATH
sudo chmod +x $MONITOR_SCRIPT_PATH

# Copy supporting files
echo "Installing supporting files..."
sudo cp adb_info.py sleep_monitor.py adb-monitor.yml /usr/local/bin/
sudo chmod +x /usr/local/bin/adb_info.py
sudo chmod +x /usr/local/bin/sleep_monitor.py

# Create LaunchAgent plist file
echo "Creating LaunchAgent plist for ADB status HTTP service..."
cat > /tmp/com.user.adb-status.plist << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.user.adb-status</string>
  <key>ProgramArguments</key>
  <array>
    <string>/usr/bin/python3</string>
    <string>/usr/local/bin/adb-status-httpd.py</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <true/>
  <key>StandardErrorPath</key>
  <string>${HOME}/Library/Logs/adb-status.log</string>
  <key>StandardOutPath</key>
  <string>${HOME}/Library/Logs/adb-status.log</string>
</dict>
</plist>
EOF

# Replace your current plist
cp /tmp/com.user.adb-status.plist "$PLIST_PATH"
chmod 644 "$PLIST_PATH"

# Create LaunchAgent for the ADB monitor
echo "Creating LaunchAgent for ADB monitor service..."
cat > /tmp/com.user.adb-monitor.plist << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.user.adb-monitor</string>
  <key>ProgramArguments</key>
  <array>
    <string>/usr/bin/python3</string>
    <string>/usr/local/bin/adb_monitor.py</string>
    <string>-d</string>
    <string>-l</string>
    <string>${HOME}/Library/Logs/adb-monitor.log</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <true/>
  <key>StandardErrorPath</key>
  <string>${HOME}/Library/Logs/adb-monitor-error.log</string>
  <key>StandardOutPath</key>
  <string>${HOME}/Library/Logs/adb-monitor-error.log</string>
</dict>
</plist>
EOF

# Install monitor plist
cp /tmp/com.user.adb-monitor.plist "$HOME/Library/LaunchAgents/com.user.adb-monitor.plist"
chmod 644 "$HOME/Library/LaunchAgents/com.user.adb-monitor.plist"

# Load the launch agents
echo "Loading LaunchAgents..."
launchctl load "$PLIST_PATH"
launchctl load "$HOME/Library/LaunchAgents/com.user.adb-monitor.plist"

echo "Installation complete!"
echo "ADB status service is running on port 8999."
echo "ADB monitor service is now running in the background."
echo "You can check service status with: launchctl list | grep adb"
echo "Log files are located at:"
echo "  - ${HOME}/Library/Logs/adb-status.log"
echo "  - ${HOME}/Library/Logs/adb-monitor.log"
echo "  - ${HOME}/Library/Logs/adb-monitor-error.log"