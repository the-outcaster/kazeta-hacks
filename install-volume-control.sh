#!/bin/bash

# This script installs the standalone volume control service for Kazeta OS on handhelds.
# It must be run with sudo or as the root user.

# --- Safety Check: Ensure script is run as root ---
if [ "$EUID" -ne 0 ]; then
  echo "Please run this script with sudo or as root."
  exit 1
fi

echo "--- Volume Control Installer (Corrected Version) ---"

# --- Define File Paths and Content ---
SCRIPT_PATH="/usr/local/bin/kazeta-volume-control.sh"
SERVICE_PATH="/etc/systemd/system/kazeta-volume-control.service"

# Use a 'here document' (cat <<'EOF') to write the script content.
echo "1. Creating the final volume control script at $SCRIPT_PATH..."
cat > "$SCRIPT_PATH" << 'EOF'
#!/bin/bash

# --- USER CONFIGURATION ---
DEVICE_NAME_PRIMARY="InputPlumber Keyboard"
DEVICE_ID_PATH_FALLBACK="platform-i8042-serio-0"
USER_UID="1000"
# --- END CONFIGURATION ---

# --- Auto-Detection & Retry Logic ---
find_device_path() {
    local device_path=""
    # 1. Check for primary device by NAME
    device_path=$(sed -n "/N: Name=\"$DEVICE_NAME_PRIMARY\"/,/H: Handlers=/ { /H: Handlers=/ { s/.*\(event[0-9]\+\).*/\1/p; q } }" /proc/bus/input/devices 2>/dev/null)
    if [ -n "$device_path" ]; then
        echo "/dev/input/$device_path"
        return
    fi
    # 2. Check for fallback device by ID_PATH
    device_path=$(grep -B 2 -E "ID_PATH=$DEVICE_ID_PATH_FALLBACK" /run/udev/data/+input:event* 2>/dev/null | grep -o 'event[0-9]\+$' | head -n 1)
    if [ -n "$device_path" ]; then
        echo "/dev/input/$device_path"
        return
    fi
}

echo "Searching for volume control device..."
INPUT_DEVICE_PATH=""
MAX_RETRIES=15
RETRY_COUNT=0

while [ -z "$INPUT_DEVICE_PATH" ] && [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    INPUT_DEVICE_PATH=$(find_device_path)
    if [ -z "$INPUT_DEVICE_PATH" ]; then
        # Log to system journal if running as a service
        if systemctl is-active --quiet kazeta-volume-control.service; then
            echo "Device not found, waiting... ($((RETRY_COUNT+1))/$MAX_RETRIES)" | systemd-cat -p info
        else
            echo "Device not found, waiting... ($((RETRY_COUNT+1))/$MAX_RETRIES)"
        fi
        sleep 1
        RETRY_COUNT=$((RETRY_COUNT+1))
    fi
done

if [ -z "$INPUT_DEVICE_PATH" ]; then
    if systemctl is-active --quiet kazeta-volume-control.service; then
        echo "ERROR: Could not find a suitable input device after $MAX_RETRIES seconds. Exiting." | systemd-cat -p err
    else
        echo "ERROR: Could not find a suitable input device after $MAX_RETRIES seconds. Exiting."
    fi
    exit 1
fi

# --- End Auto-Detection ---

stdbuf -o0 od -An -t u2 -j 16 -w8 "$INPUT_DEVICE_PATH" | while read -r type code value junk; do
  if [ "$type" -eq 1 ]; then
    if [ "$value" -eq 1 ] || [ "$value" -eq 2 ]; then
      case "$code" in
        115) # KEY_VOLUMEUP
          env XDG_RUNTIME_DIR=/run/user/$USER_UID wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ 10%+
          env XDG_RUNTIME_DIR=/run/user/$USER_UID wpctl get-volume @DEFAULT_AUDIO_SINK@
          ;;
        114) # KEY_VOLUMEDOWN
          env XDG_RUNTIME_DIR=/run/user/$USER_UID wpctl set-volume @DEFAULT_AUDIO_SINK@ 10%-
          env XDG_RUNTIME_DIR=/run/user/$USER_UID wpctl get-volume @DEFAULT_AUDIO_SINK@
          ;;
      esac
    fi
  fi
done
EOF

# Create the systemd service file
echo "2. Creating the systemd service at $SERVICE_PATH..."
cat > "$SERVICE_PATH" << 'EOF'
[Unit]
Description=Standalone volume control script for handhelds
Wants=user@1000.service
After=user@1000.service

[Service]
Type=simple
ExecStart=/usr/local/bin/kazeta-volume-control.sh
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# --- Final Steps ---
echo "3. Setting script permissions..."
chmod +x "$SCRIPT_PATH"

echo "4. Reloading systemd and restarting the service..."
systemctl daemon-reload
systemctl enable --now "$SERVICE_PATH"

echo ""
echo "Installation complete!"
echo "The corrected volume control service is now running."
echo "Please reboot to confirm everything works correctly from a cold start."
