#!/bin/bash

# ==========================================
# NetworkManager Python Trigger Setup Script
# ==========================================

# 1. Root privilege check
if [ "$EUID" -ne 0 ]; then
  echo "Error: Please run this script as root (use sudo)."
  exit 1
fi

# Configuration variables
APP_NAME="unimore-login"
APP_DIR="/var/opt/$APP_NAME"
ETC_DIR="/etc/$APP_NAME"
CRED_FILE="$ETC_DIR/credentials.json"
DISPATCHER_DIR="/etc/NetworkManager/dispatcher.d"
DISPATCHER_SCRIPT="$DISPATCHER_DIR/99-$APP_NAME"

echo "=== Network Automation Setup ==="

# 2. Prompt user for configuration parameters
read -p "Enter the connection name (SSID) to monitor: " TARGET_SSID
read -p "Enter the application username: " APP_USER
# -s flag hides the password input
read -s -p "Enter the application password: " APP_PASS
echo "" # Newline after hidden input

# 3. Create necessary directories
echo "[*] Creating directories in /var/opt and /etc..."
mkdir -p "$APP_DIR"
mkdir -p "$ETC_DIR"

# 4. Securely create the JSON credentials file
echo "[*] Saving credentials securely to $CRED_FILE..."
cat <<EOF > "$CRED_FILE"
{
    "username": "$APP_USER",
    "password": "$APP_PASS"
}
EOF

# Restrictive permissions: only root can read/write the JSON file
chown root:root "$CRED_FILE"
chmod 600 "$CRED_FILE"

# 5. Install the Python script and Virtual Environment
echo "[*] Copying application files to $APP_DIR..."
# Copy the Python script (ensure it is named main.py and in the current directory)
if [ -f "main.py" ]; then
    cp main.py "$APP_DIR/"
else
    echo "[!] Warning: 'main.py' not found in the current directory."
    echo "    Remember to copy your script to $APP_DIR/main.py manually."
fi

# Create a clean Virtual Environment directly in the destination
echo "[*] Creating Python Virtual Environment in $APP_DIR/venv..."
python3 -m venv "$APP_DIR/venv"

# Install the requirements
$APP_DIR/venv/bin/pip install -r ./requirements.txt >> /dev/null


# Set correct ownership for the application directory
chown -R root:root "$APP_DIR"
chmod -R 755 "$APP_DIR"

# 6. Create the NetworkManager Dispatcher Script
echo "[*] Creating dispatcher script at $DISPATCHER_SCRIPT..."

# Generate the script dynamically. Note the backslash (\) to prevent 
# system variables from expanding during creation.
cat <<EOF > "$DISPATCHER_SCRIPT"
#!/bin/bash

# Auto-generated configuration
TARGET_SSID="$TARGET_SSID"
PYTHON_BIN="$APP_DIR/venv/bin/python3"
SCRIPT_PATH="$APP_DIR/main.py"
LOG_FILE="/var/log/${APP_NAME}_dispatcher.log"

if [ "\$CONNECTION_ID" = "\$TARGET_SSID" ] && [ "\$2" = "up" ]; then
    echo "\$(date): Connection '\$TARGET_SSID' established. Starting script..." >> "\$LOG_FILE"
    \$PYTHON_BIN \$SCRIPT_PATH >> "\$LOG_FILE" 2>&1
fi
EOF

# Permissions for the dispatcher (MUST be executable by root, not writable by others)
chown root:root "$DISPATCHER_SCRIPT"
chmod 755 "$DISPATCHER_SCRIPT"

echo "=== Setup completed successfully! ==="
echo "- Application installed in: $APP_DIR"
echo "- Credentials saved in:     $CRED_FILE (Permissions: 600)"
echo "- Dispatcher configured for: $TARGET_SSID"
echo "- Log file set to:          /var/log/${APP_NAME}_dispatcher.log"
